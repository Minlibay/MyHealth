#import "RingBlePlugin.h"
#import "BleSDK_X3.h"
#import "DeviceData_X3.h"

// BLE UUID кольца JCRing X3 (Jstyle): сервис fff0, запись fff6, нотификации fff7.
static NSString *const kService = @"FFF0";
static NSString *const kWrite   = @"FFF6";
static NSString *const kNotify  = @"FFF7";

@interface RingBlePlugin ()
@property(nonatomic, strong) CBCentralManager *central;
@property(nonatomic, strong) CBPeripheral *peripheral;
@property(nonatomic, strong) CBCharacteristic *writeChar;
@property(nonatomic, strong) NSMutableDictionary<NSString *, CBPeripheral *> *found;
@property(nonatomic, copy, nullable) FlutterEventSink sink;
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
        _central = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
    }
    return self;
}

#pragma mark - Flutter channels

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([call.method isEqualToString:@"startScan"]) {
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
    if (self.central.state != CBManagerStatePoweredOn) { [self emitState:@"failed"]; return; }
    [self emitState:@"scanning"];
    [self.central scanForPeripheralsWithServices:nil options:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(12 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self.central stopScan]; });
}

- (void)connect:(NSString *)deviceId {
    [self.central stopScan];
    CBPeripheral *p = self.found[deviceId];
    if (!p) { [self emitState:@"failed"]; return; }
    self.peripheral = p;
    p.delegate = self;
    [self emitState:@"connecting"];
    [self.central connectPeripheral:p options:nil];
}

- (void)disconnect {
    if (self.peripheral) [self.central cancelPeripheralConnection:self.peripheral];
    self.peripheral = nil;
    self.writeChar = nil;
    [self emitState:@"disconnected"];
}

- (void)measure {
    // 1 = пульс (см. документацию SDK по типам реального времени).
    [self write:[[BleSDK_X3 sharedManager] RealTimeDataWithType:1]];
    [self write:[[BleSDK_X3 sharedManager] GetDeviceBatteryLevel]];
}

- (void)write:(NSData *)data {
    if (!data || !self.writeChar || !self.peripheral) return;
    [self.peripheral writeValue:data forCharacteristic:self.writeChar
                           type:CBCharacteristicWriteWithoutResponse];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary<NSString *, id> *)advertisementData
                  RSSI:(NSNumber *)RSSI {
    if (peripheral.name.length == 0) return;
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
    if (!d) return;

    NSMutableDictionary *out = [@{@"type": @"data"} mutableCopy];
    [self copyNumber:d keys:@[@"HeartRate", @"heartValue"] to:out as:@"heartRate"];
    [self copyNumber:d keys:@[@"Sp02"] to:out as:@"spo2"];
    [self copyNumber:d keys:@[@"Final_temperature_value"] to:out as:@"temperature"];
    [self copyNumber:d keys:@[@"hrvValue"] to:out as:@"hrv"];
    [self copyNumber:d keys:@[@"Power", @"battery", @"Battery"] to:out as:@"battery"];
    [self copyNumber:d keys:@[@"Step", @"StepValue", @"steps"] to:out as:@"steps"];
    if (out.count > 1) [self emit:out];
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
