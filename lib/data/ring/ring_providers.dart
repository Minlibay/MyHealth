import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ring_models.dart';
import 'ring_service.dart';
import 'ring_service_factory.dart';

final ringServiceProvider = Provider<RingService>((ref) {
  final service = createRingService();
  ref.onDispose(service.dispose);
  return service;
});

final ringScanProvider = StreamProvider<List<RingDevice>>(
    (ref) => ref.watch(ringServiceProvider).scanResults);

final ringConnectionProvider = StreamProvider<RingConnState>(
    (ref) => ref.watch(ringServiceProvider).connectionState);

final ringLiveDataProvider = StreamProvider<RingLiveData>(
    (ref) => ref.watch(ringServiceProvider).liveData);
