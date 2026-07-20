#import "RingBlePlugin.h"
#import "BleSDK_X3.h"
#import "BleSDK_Header_X3.h"
#import "DeviceData_X3.h"

// BLE UUID кольца JCRing X3 (Jstyle): сервис fff0, запись fff6, нотификации fff7.
static NSString *const kService = @"FFF0";
static NSString *const kWrite   = @"FFF6";
static NSString *const kNotify  = @"FFF7";

// Таймаут одного шага истории: нет ответа — переходим к следующему типу.
static const NSTimeInterval kHistoryStepTimeout = 15.0;
// Пауза между записями в характеристику (write without response).
static const NSTimeInterval kWriteSpacing = 0.15;

/// Один тип истории: имя для Flutter + dataType SDK + генератор команды.
/// altDataType — запасной тип ответа (некоторые прошивки отвечают
/// соседним типом, например температура как AxillaryTemperature).
@interface RingHistoryKind : NSObject
@property(nonatomic, copy) NSString *name;
@property(nonatomic, assign) NSInteger dataType;
@property(nonatomic, assign) NSInteger altDataType;
@property(nonatomic, copy) NSMutableData *(^command)(int mode);
@end

@implementation RingHistoryKind
+ (instancetype)name:(NSString *)name
            dataType:(NSInteger)dataType
             command:(NSMutableData *(^)(int))command {
    RingHistoryKind *k = [RingHistoryKind new];
    k.name = name;
    k.dataType = dataType;
    k.altDataType = -1;
    k.command = command;
    return k;
}

- (BOOL)matches:(NSInteger)dataType {
    return dataType == self.dataType || dataType == self.altDataType;
}
@end

@interface RingBlePlugin ()
@property(nonatomic, strong) CBCentralManager *central;
@property(nonatomic, strong) CBPeripheral *peripheral;
@property(nonatomic, strong) CBCharacteristic *writeChar;
@property(nonatomic, strong) NSMutableDictionary<NSString *, CBPeripheral *> *found;
@property(nonatomic, copy, nullable) FlutterEventSink sink;

// Очередь записи: команды уходят с паузой, иначе кольцо теряет пакеты.
@property(nonatomic, strong) NSMutableArray<NSData *> *writeQueue;
@property(nonatomic, assign) BOOL writing;

// Синхронизация истории.
@property(nonatomic, strong) NSMutableArray<RingHistoryKind *> *historyQueue;
@property(nonatomic, strong, nullable) RingHistoryKind *currentKind;
@property(nonatomic, assign) NSInteger historyGeneration;

// CBCentralManager включается асинхронно: команды до poweredOn откладываем.
@property(nonatomic, assign) BOOL pendingScan;
@property(nonatomic, copy, nullable) NSString *pendingConnectId;

// true — показывать все устройства с именем (нестандартные имена Jstyle).
@property(nonatomic, assign) BOOL showAllDevices;
@end

@implementation RingBlePlugin

+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    RingBlePlugin *instance = [[RingBlePlugin alloc] init];
    FlutterMethodChannel *methods =
        [FlutterMethodChannel methodChannelWithName:@"jcring_x3/methods"
                                    binaryMessenger:[registrar messenger]];
    [registrar addMethodCallDelegate:instance channel:methods];
    FlutterEventChannel *events =
        [FlutterEventChannel eventChannelWithName:@"jcring_x3/events"
                                  binaryMessenger:[registrar messenger]];
    [events setStreamHandler:instance];
}

- (instancetype)init {
    if (self = [super init]) {
        _found = [NSMutableDictionary dictionary];
        _writeQueue = [NSMutableArray array];
        _historyQueue = [NSMutableArray array];
        _central = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

#pragma mark - Flutter channels

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([call.method isEqualToString:@"startScan"]) {
        NSDictionary *args = [call.arguments isKindOfClass:[NSDictionary class]]
            ? call.arguments : @{};
        self.showAllDevices = [args[@"showAll"] boolValue];
        [self startScan];
        result(nil);
    } else if ([call.method isEqualToString:@"stopScan"]) {
        [self.central stopScan];
        result(nil);
    } else if ([call.method isEqualToString:@"connect"]) {
        [self connect:call.arguments[@"id"]];
        result(nil);
    } else if ([call.method isEqualToString:@"disconnect"]) {
        [self disconnect];
        result(nil);
    } else if ([call.method isEqualToString:@"measure"]) {
        [self measure];
        result(nil);
    } else if ([call.method isEqualToString:@"syncHistory"]) {
        [self syncHistory];
        result(nil);
    } else if ([call.method isEqualToString:@"setProfile"]) {
        NSDictionary *a = call.arguments;
        [self setProfileGender:[a[@"gender"] intValue]
                           age:[a[@"age"] intValue]
                        height:[a[@"height"] intValue]
                        weight:[a[@"weight"] intValue]];
        result(nil);
    } else if ([call.method isEqualToString:@"enableAutoMonitoring"]) {
        [self enableAutoMonitoring:[call.arguments[@"intervalMinutes"] intValue]];
        result(nil);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

- (FlutterError *)onListenWithArguments:(id)args eventSink:(FlutterEventSink)sink {
    self.sink = sink;
    return nil;
}

- (FlutterError *)onCancelWithArguments:(id)args {
    self.sink = nil;
    return nil;
}

- (void)emit:(NSDictionary *)event {
    if (self.sink) {
        dispatch_async(dispatch_get_main_queue(), ^{ if (self.sink) self.sink(event); });
    }
}

- (void)emitState:(NSString *)state {
    [self emit:@{@"type": @"state", @"state": state}];
}

#pragma mark - Commands

- (void)startScan {
    [self.found removeAllObjects];
    if (self.central.state != CBManagerStatePoweredOn) {
        // Bluetooth выключен/запрещён — это настоящая ошибка. Состояния
        // unknown/resetting — стек ещё включается: подождём poweredOn.
        if (self.central.state == CBManagerStatePoweredOff ||
            self.central.state == CBManagerStateUnauthorized ||
            self.central.state == CBManagerStateUnsupported) {
            [self emitState:@"failed"];
        } else {
            self.pendingScan = YES;
            [self emitState:@"scanning"];
        }
        return;
    }
    [self emitState:@"scanning"];
    [self.central scanForPeripheralsWithServices:nil options:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self.central stopScan]; });
}

- (void)connect:(NSString *)deviceId {
    if (self.central.state != CBManagerStatePoweredOn) {
        // Автоподключение при старте приложения: стек ещё включается —
        // подключимся из centralManagerDidUpdateState.
        self.pendingConnectId = deviceId;
        [self emitState:@"connecting"];
        return;
    }
    [self.central stopScan];
    CBPeripheral *p = self.found[deviceId];
    if (!p) {
        // Переподключение после перезапуска: устройства нет в результатах
        // скана — восстанавливаем CBPeripheral по сохранённому идентификатору.
        NSUUID *uuid = [[NSUUID alloc] initWithUUIDString:deviceId];
        if (uuid) {
            NSArray *known = [self.central retrievePeripheralsWithIdentifiers:@[uuid]];
            if (known.count > 0) {
                p = known.firstObject;
                self.found[deviceId] = p;
            }
        }
    }
    if (!p) { [self emitState:@"failed"]; return; }
    self.peripheral = p;
    p.delegate = self;
    [self emitState:@"connecting"];
    [self.central connectPeripheral:p options:nil];
}

- (void)disconnect {
    [self cancelHistorySync];
    if (self.peripheral) [self.central cancelPeripheralConnection:self.peripheral];
    self.peripheral = nil;
    self.writeChar = nil;
    [self.writeQueue removeAllObjects];
    self.writing = NO;
    [self emitState:@"disconnected"];
}

- (void)measure {
    // Синхронизируем часы кольца, затем включаем живой поток.
    NSDate *now = [NSDate date];
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *c = [cal components:(NSCalendarUnitYear | NSCalendarUnitMonth |
                                           NSCalendarUnitDay | NSCalendarUnitHour |
                                           NSCalendarUnitMinute | NSCalendarUnitSecond)
                                 fromDate:now];
    MyDeviceTime_X3 t = { (int)c.year, (int)c.month, (int)c.day,
                          (int)c.hour, (int)c.minute, (int)c.second };
    [self enqueueWrite:[[BleSDK_X3 sharedManager] SetDeviceTime:t]];
    // 1 = пульс (см. документацию SDK по типам реального времени).
    [self enqueueWrite:[[BleSDK_X3 sharedManager] RealTimeDataWithType:1]];
    [self enqueueWrite:[[BleSDK_X3 sharedManager] GetDeviceBatteryLevel]];
}

/// Профиль пользователя — точность калорий и дистанции.
- (void)setProfileGender:(int)gender age:(int)age height:(int)height weight:(int)weight {
    MyPersonalInfo_X3 info = { gender, age, height, weight, 70 };
    [self enqueueWrite:[[BleSDK_X3 sharedManager] SetPersonalInfo:info]];
}

/// Автозамеры: интервальный режим на весь день, все дни недели.
- (void)enableAutoMonitoring:(int)intervalMinutes {
    MyWeeks_X3 all = { YES, YES, YES, YES, YES, YES, YES };
    for (int sensor = 1; sensor <= 4; sensor++) { // 1=HR, 2=SpO2, 3=temp, 4=HRV
        MyAutomaticMonitoring_X3 cfg;
        cfg.mode = 2; // интервальные замеры внутри окна
        cfg.startTime_Hour = 0;
        cfg.startTime_Minutes = 0;
        cfg.endTime_Hour = 23;
        cfg.endTime_Minutes = 59;
        cfg.weeks = all;
        cfg.intervalTime = intervalMinutes;
        cfg.dataType = sensor;
        [self enqueueWrite:[[BleSDK_X3 sharedManager] SetAutomaticHRMonitoring:cfg]];
    }
}

/// Типы истории (порядок = порядок выкачивания).
- (NSArray<RingHistoryKind *> *)historyKinds {
    BleSDK_X3 *sdk = [BleSDK_X3 sharedManager];
    return @[
        [RingHistoryKind name:@"activity" dataType:TotalActivityData_X3
                      command:^(int m) { return [sdk GetTotalActivityDataWithMode:m withStartDate:nil]; }],
        [RingHistoryKind name:@"sleep" dataType:DetailSleepData_X3
                      command:^(int m) { return [sdk GetDetailSleepDataWithMode:m withStartDate:nil]; }],
        [RingHistoryKind name:@"dynamicHr" dataType:DynamicHR_X3
                      command:^(int m) { return [sdk GetContinuousHRDataWithMode:m withStartDate:nil]; }],
        [RingHistoryKind name:@"staticHr" dataType:StaticHR_X3
                      command:^(int m) { return [sdk GetSingleHRDataWithMode:m withStartDate:nil]; }],
        [RingHistoryKind name:@"hrv" dataType:HRVData_X3
                      command:^(int m) { return [sdk GetHRVDataWithMode:m withStartDate:nil]; }],
        [RingHistoryKind name:@"spo2" dataType:AutomaticSpo2Data_X3
                      command:^(int m) { return [sdk GetAutomaticSpo2DataWithMode:m withStartDate:nil]; }],
        ({
            RingHistoryKind *temp =
                [RingHistoryKind name:@"temperature" dataType:TemperatureData_X3
                              command:^(int m) { return [sdk GetTemperatureDataWithMode:m withStartDate:nil]; }];
            temp.altDataType = AxillaryTemperatureData_X3;
            temp;
        }),
    ];
}

- (void)syncHistory {
    if (!self.peripheral || !self.writeChar) {
        [self emit:@{@"type": @"historyDone", @"ok": @NO, @"error": @"not_connected"}];
        return;
    }
    [self cancelHistorySync];
    [self.historyQueue setArray:[self historyKinds]];
    [self nextHistoryKind];
}

- (void)cancelHistorySync {
    self.historyGeneration += 1;
    [self.historyQueue removeAllObjects];
    self.currentKind = nil;
}

- (void)nextHistoryKind {
    if (self.historyQueue.count == 0) {
        self.currentKind = nil;
        [self emit:@{@"type": @"historyDone", @"ok": @YES}];
        return;
    }
    RingHistoryKind *kind = self.historyQueue.firstObject;
    [self.historyQueue removeObjectAtIndex:0];
    self.currentKind = kind;
    [self enqueueWrite:kind.command(0)];
    [self armHistoryTimeout];
}

- (void)armHistoryTimeout {
    self.historyGeneration += 1;
    NSInteger generation = self.historyGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kHistoryStepTimeout * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        typeof(self) self = weakSelf;
        if (!self || self.historyGeneration != generation) return;
        // Кольцо не ответило по текущему типу — идём дальше.
        if (self.currentKind) [self nextHistoryKind];
    });
}

#pragma mark - Write queue

- (void)enqueueWrite:(NSData *)data {
    if (!data) return;
    [self.writeQueue addObject:data];
    [self drainWriteQueue];
}

- (void)drainWriteQueue {
    if (self.writing || !self.writeChar || !self.peripheral) return;
    if (self.writeQueue.count == 0) return;
    NSData *data = self.writeQueue.firstObject;
    [self.writeQueue removeObjectAtIndex:0];
    self.writing = YES;
    [self.peripheral writeValue:data forCharacteristic:self.writeChar
                           type:CBCharacteristicWriteWithoutResponse];
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kWriteSpacing * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        weakSelf.writing = NO;
        [weakSelf drainWriteQueue];
    });
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        NSString *connectId = self.pendingConnectId;
        self.pendingConnectId = nil;
        if (connectId) [self connect:connectId];
        if (self.pendingScan) {
            self.pendingScan = NO;
            [self startScan];
        }
    } else if (central.state == CBManagerStatePoweredOff ||
               central.state == CBManagerStateUnauthorized) {
        // Отложенный скан больше не выполнится — сообщаем об ошибке.
        if (self.pendingScan) {
            self.pendingScan = NO;
            [self emitState:@"failed"];
        }
    }
}

/// Показываем устройства Jstyle (кольца и браслеты): либо рекламируется
/// сервис fff0, либо имя похоже на носимое устройство — иначе в списке
/// оказываются все BLE-устройства вокруг.
- (BOOL)isWearableDevice:(CBPeripheral *)peripheral
       advertisementData:(NSDictionary<NSString *, id> *)advertisementData {
    NSArray *services = advertisementData[CBAdvertisementDataServiceUUIDsKey];
    for (CBUUID *uuid in services) {
        if ([uuid isEqual:[CBUUID UUIDWithString:kService]]) return YES;
    }
    NSString *advName = advertisementData[CBAdvertisementDataLocalNameKey];
    NSString *name = [(peripheral.name ?: advName ?: @"") lowercaseString];
    for (NSString *marker in @[@"ring", @"jc", @"jstyle", @"j-style", @"x3",
                               @"2301", @"band", @"bracelet", @"smart"]) {
        if ([name containsString:marker]) return YES;
    }
    return NO;
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *, id> *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    if (peripheral.name.length == 0) return;
    if (!self.showAllDevices &&
        ![self isWearableDevice:peripheral advertisementData:advertisementData]) return;
    self.found[peripheral.identifier.UUIDString] = peripheral;
    NSMutableArray *devices = [NSMutableArray array];
    for (CBPeripheral *p in self.found.allValues) {
        [devices addObject:@{@"id": p.identifier.UUIDString,
                             @"name": p.name ?: @"Кольцо",
                             @"rssi": RSSI ?: @0}];
    }
    [self emit:@{@"type": @"scan", @"devices": devices}];
}

- (void)centralManager:(CBCentralManager *)central
  didConnectPeripheral:(CBPeripheral *)peripheral {
    [peripheral discoverServices:@[[CBUUID UUIDWithString:kService]]];
}

- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self cancelHistorySync];
    [self emitState:@"disconnected"];
}

- (void)centralManager:(CBCentralManager *)central
didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self emitState:@"failed"];
}

#pragma mark - CBPeripheralDelegate

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    for (CBService *s in peripheral.services) {
        if ([s.UUID isEqual:[CBUUID UUIDWithString:kService]]) {
            [peripheral discoverCharacteristics:nil forService:s];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    for (CBCharacteristic *c in service.characteristics) {
        if ([c.UUID isEqual:[CBUUID UUIDWithString:kWrite]]) {
            self.writeChar = c;
        } else if ([c.UUID isEqual:[CBUUID UUIDWithString:kNotify]]) {
            [peripheral setNotifyValue:YES forCharacteristic:c];
        }
    }
    [self emitState:@"connected"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self measure]; });
}

- (void)peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (![characteristic.UUID isEqual:[CBUUID UUIDWithString:kNotify]]) return;
    if (!characteristic.value) return;
    DeviceData_X3 *parsed = [[BleSDK_X3 sharedManager] DataParsingWithData:characteristic.value];
    NSDictionary *d = parsed.dicData;

    // История: диспетчеризация по dataType текущего шага.
    RingHistoryKind *kind = self.currentKind;
    if (kind && [kind matches:parsed.dataType]) {
        NSArray *records = [self recordsFromDicData:d];
        if (records.count > 0) {
            [self emit:@{@"type": @"history", @"kind": kind.name, @"records": records}];
        }
        if (parsed.dataEnd) {
            [self nextHistoryKind];
        } else {
            [self enqueueWrite:kind.command(2)]; // продолжение чтения
            [self armHistoryTimeout];
        }
        return;
    }

    if (!d) return;

    // Живые данные и батарея.
    NSMutableDictionary *out = [@{@"type": @"data"} mutableCopy];
    if (parsed.dataType == RealTimeStep_X3) {
        [self copyNumber:d keys:@[@"HeartRate", @"heartRate", @"heartValue"] to:out as:@"heartRate"];
        [self copyNumber:d keys:@[@"Blood_oxygen", @"spo2", @"Sp02"] to:out as:@"spo2"];
        [self copyNumber:d keys:@[@"TempData", @"temperature", @"Final_temperature_value"] to:out as:@"temperature"];
        [self copyNumber:d keys:@[@"step", @"Step", @"steps"] to:out as:@"steps"];
    } else if (parsed.dataType == GetDeviceBattery_X3) {
        [self copyNumber:d keys:@[@"batteryLevel", @"Power", @"battery"] to:out as:@"battery"];
    } else {
        return;
    }
    if (out.count > 1) [self emit:out];
}

/// Записи истории лежат в dicData под ключом "array..." (имя зависит от
/// типа) — берём первый NSArray и приводим значения к строкам.
- (NSArray *)recordsFromDicData:(NSDictionary *)d {
    if (![d isKindOfClass:[NSDictionary class]]) return @[];
    NSArray *list = nil;
    for (id value in d.allValues) {
        if ([value isKindOfClass:[NSArray class]]) { list = value; break; }
    }
    if (!list) {
        // Некоторые ответы — одна запись без вложенного массива.
        return @[[self stringifyRecord:d]];
    }
    NSMutableArray *records = [NSMutableArray arrayWithCapacity:list.count];
    for (id item in list) {
        if ([item isKindOfClass:[NSDictionary class]]) {
            [records addObject:[self stringifyRecord:item]];
        }
    }
    return records;
}

- (NSDictionary *)stringifyRecord:(NSDictionary *)record {
    NSMutableDictionary *out = [NSMutableDictionary dictionaryWithCapacity:record.count];
    [record enumerateKeysAndObjectsUsingBlock:^(id key, id value, BOOL *stop) {
        if ([value isKindOfClass:[NSDictionary class]]) return;
        if ([value isKindOfClass:[NSArray class]]) {
            // Массивы скаляров (фазы сна, поминутные шаги) — строкой через
            // пробел, как это делает Android-SDK.
            NSMutableArray *parts = [NSMutableArray array];
            for (id item in (NSArray *)value) {
                if ([item isKindOfClass:[NSDictionary class]] ||
                    [item isKindOfClass:[NSArray class]]) continue;
                [parts addObject:[item description]];
            }
            out[[key description]] = [parts componentsJoinedByString:@" "];
            return;
        }
        out[[key description]] = [value description];
    }];
    return out;
}

- (void)copyNumber:(NSDictionary *)src keys:(NSArray<NSString *> *)keys
                to:(NSMutableDictionary *)dst as:(NSString *)dstKey {
    for (NSString *k in keys) {
        id v = src[k];
        if ([v isKindOfClass:[NSNumber class]]) { dst[dstKey] = v; return; }
        if ([v isKindOfClass:[NSString class]]) { dst[dstKey] = @([v doubleValue]); return; }
    }
}

@end
