#import <Flutter/Flutter.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

/// Мост Flutter ↔ нативный SDK кольца JCRing X3 (CoreBluetooth + BleSDK_X3).
/// Каналы: method 'jcring_x3/methods', event 'jcring_x3/events'.
@interface RingBlePlugin : NSObject <FlutterPlugin, FlutterStreamHandler,
                                     CBCentralManagerDelegate, CBPeripheralDelegate>
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar;
@end

NS_ASSUME_NONNULL_END
