# Сборка iOS на Codemagic

Что уже подготовлено в репозитории:
- `ios/BleSDK/` — статическая либа `libBleSDK.a` + заголовки + Obj-C мост `RingBlePlugin`.
- `ios/BleSDK/BleSDKX3.podspec` — локальный CocoaPods-под (либа + мост + CoreBluetooth).
- `ios/Podfile` — подключает под `BleSDKX3`.
- `ios/Runner/Runner-Bridging-Header.h` — импорт заголовков SDK для Swift.
- `ios/Runner/AppDelegate.swift` — регистрация `RingBlePlugin`.
- `ios/Runner/Info.plist` — описания доступа к HealthKit и Bluetooth.
- `ios/Flutter/{Debug,Release}.xcconfig` — `CODE_SIGN_ENTITLEMENTS` → `Runner.entitlements` (HealthKit).
- `codemagic.yaml` — workflow'ы `ios-compile-check`, `ios-release`, `android-release`.

## Порядок действий

1. **Сначала проверь компиляцию** — запусти workflow `ios-compile-check`
   (`flutter build ios --no-codesign`). Подпись не нужна; проверяет, что
   натив (под + мост + Swift) собирается. Здесь, скорее всего, всплывут
   мелочи в нативном коде — их правим по логам Xcode.

2. **Apple Developer (обязательно для подписанной сборки и реального устройства):**
   - В App ID `com.myhealth.app` включить capability **HealthKit**.
   - Bluetooth отдельного entitlement не требует (хватает строк в Info.plist).
   - Создать App в App Store Connect, прописать его Apple ID в `codemagic.yaml`
     (`APP_STORE_APPLE_ID`).

3. **Подпись в Codemagic:**
   - Подключить интеграцию **App Store Connect** (API-ключ) — в `codemagic.yaml`
     это `integrations.app_store_connect: codemagic` (замени на имя своей интеграции).
   - Блок `ios_signing` уже настроен на `app_store` + `com.myhealth.app`.

## Важные нюансы / возможные правки
- **Архитектура либы:** `libBleSDK.a` собрана под устройство (**arm64**), не под
  симулятор. Поэтому в подспеке `VALID_ARCHS = arm64`; сборки только под device/IPA.
- **Тип реального времени:** в `RingBlePlugin.m` команда `RealTimeDataWithType:1`
  (пульс). Точные коды типов и ключи `dicData` сверь с «IOS SDK Documentation.docx»
  из архива SDK — при необходимости поправь маппинг.
- **Версия iOS:** таргет **14.0** (требование плагина `health`) — в Podfile, podspec и
  `project.pbxproj` (`IPHONEOS_DEPLOYMENT_TARGET = 14.0`).
- Мост и парсинг на iOS **не проверялись на устройстве** (нет Mac в среде разработки) —
  первый прогон на Codemagic/реальном кольце может потребовать мелких правок.

## Частые ошибки первого прогона и фиксы

1. **`'RingBlePlugin.h' file not found`** (или `BleSDK_X3.h`) при компиляции Swift/мост.
   Значит, под собирается как фреймворк (modular). Фикс — угловые скобки в
   `ios/Runner/Runner-Bridging-Header.h`:
   `#import <BleSDKX3/RingBlePlugin.h>` вместо `#import "RingBlePlugin.h"`.
   Если наоборот не находит при статической линковке — вернуть кавычки.

2. **Swift не видит `RingBlePlugin`** → проверь, что bridging-header импортирует его
   и что в Build Settings `SWIFT_OBJC_BRIDGING_HEADER = Runner/Runner-Bridging-Header.h`
   (по умолчанию так).

3. **`Undefined symbols ... arm64` / линковка `libBleSDK.a`** → статическая либа только
   под устройство arm64. Собирать под device/IPA (наши workflow так и делают);
   симулятор не поддержан.

4. **`pod install` падает на `Flutter` dependency** → убедись, что шаг идёт после
   `flutter build ios --config-only` (он генерирует `Generated.xcconfig` и кладёт
   Flutter-под). В `ios-compile-check` это уже так.

5. **Имена методов SDK / `RealTimeDataWithType` / ключи `dicData`** → сверить с
   «IOS SDK Documentation.docx». Это правки в `ios/BleSDK/RingBlePlugin.m`
   (рантайм, не компиляция).

6. **Подпись (`ios-release`)**: ошибки provisioning → в App ID включён HealthKit,
   интеграция App Store Connect подключена, `bundle_identifier` совпадает.

## Как доводим
Запусти workflow **`ios-compile-check`** в Codemagic. Если упадёт — пришли мне
последние ~50 строк лога шага «Build iOS» (или раздел с `error:`), и я внесу правки.
