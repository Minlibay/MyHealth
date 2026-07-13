// Мост к домашнему виджету со скорами. На Web виджетов нет — заглушка.
export 'widget_bridge_stub.dart' if (dart.library.io) 'widget_bridge_io.dart';
