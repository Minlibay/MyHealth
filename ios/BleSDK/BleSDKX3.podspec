Pod::Spec.new do |s|
  s.name             = 'BleSDKX3'
  s.version          = '1.0.0'
  s.summary          = 'JCRing X3 (Jstyle) BLE SDK — vendored static library.'
  s.description      = 'Native BLE protocol SDK for the JCRing Med X3 smart ring.'
  s.homepage         = 'https://www.jstyle.com'
  s.license          = { :type => 'Proprietary', :text => 'Vendor SDK (Jstyle).' }
  s.author           = { 'Jstyle' => 'support@jstyle.com' }
  s.platform         = :ios, '14.0'

  s.source           = { :path => '.' }
  s.vendored_libraries = 'libBleSDK.a'
  s.source_files     = '*.{h,m}'
  s.public_header_files = '*.h'
  s.frameworks       = 'CoreBluetooth', 'Foundation'
  s.requires_arc     = true

  # Мост RingBlePlugin использует Flutter.
  s.dependency 'Flutter'

  # Статическая либа собрана под arm64-устройство (не симулятор).
  s.pod_target_xcconfig = { 'VALID_ARCHS' => 'arm64' }
end
