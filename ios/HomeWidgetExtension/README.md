# iOS-виджет: подключение (требуется Xcode на Mac, один раз)

Dart-сторона уже готова (`lib/widget/widget_bridge_io.dart` пишет скоры
через `home_widget`), Swift-код виджета — в `ScoreWidget.swift` рядом.
Осталось создать таргет — это невозможно сделать без Xcode:

1. Откройте `ios/Runner.xcworkspace` в Xcode.
2. File → New → Target → **Widget Extension**.
   - Product Name: `HomeWidgetExtension`
   - Снимите галочку «Include Configuration App Intent».
3. Удалите сгенерированный шаблонный swift-файл таргета и добавьте в таргет
   `ios/HomeWidgetExtension/ScoreWidget.swift` (Add Files…, membership —
   только у нового таргета).
4. Включите **App Groups** (Signing & Capabilities) и для Runner,
   и для HomeWidgetExtension, с одинаковой группой:
   `group.com.myhealthv.app`.
5. В `lib/widget/widget_bridge_io.dart` при инициализации home_widget
   группа уже согласована через `HomeWidget.setAppGroupId` — если поменяете
   имя группы, поменяйте его в обоих местах.
6. В Codemagic укажите подпись для нового таргета (тот же сертификат,
   отдельный provisioning profile с App Group).

После этого виджет «MyHealth» появится в галерее виджетов iOS.
