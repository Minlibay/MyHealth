/// Одна точка истории показателя.
/// [secondary] используется для давления (систолическое = value, диастолическое = secondary).
class MetricSample {
  const MetricSample({required this.time, required this.value, this.secondary});

  final DateTime time;
  final double value;
  final double? secondary;
}
