import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/health_metric.dart';
import 'features/consent/consent_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/metric_detail/metric_detail_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/ring/ring_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/workouts/workouts_screen.dart';
import 'providers.dart';

/// Роутер приложения. До получения согласия (GDPR) пускает только на /consent.
final routerProvider = Provider<GoRouter>((ref) {
  // Мост из Riverpod в Listenable: пересобирает роутер при смене состояния.
  final refresh = ValueNotifier<int>(0);
  ref.listen(consentControllerProvider, (_, _) => refresh.value++);
  ref.listen(onboardingControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final onboarding = ref.read(onboardingControllerProvider);
      final consent = ref.read(consentControllerProvider);
      // Пока флаги читаются из хранилища — не редиректим.
      if (onboarding.isLoading || consent.isLoading) return null;

      final onboarded = onboarding.value ?? false;
      final granted = consent.value ?? false;
      final loc = state.matchedLocation;

      if (!onboarded) return loc == '/onboarding' ? null : '/onboarding';
      if (!granted) return loc == '/consent' ? null : '/consent';
      // Онбординг и согласие пройдены — с этих экранов уводим на главную.
      if (loc == '/onboarding' || loc == '/consent') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/ring', builder: (_, _) => const RingScreen()),
      GoRoute(path: '/workouts', builder: (_, _) => const WorkoutsScreen()),
      GoRoute(
        path: '/metric/:name',
        builder: (_, state) {
          final name = state.pathParameters['name'];
          final metric = HealthMetric.values.firstWhere(
            (m) => m.name == name,
            orElse: () => HealthMetric.steps,
          );
          return MetricDetailScreen(metric: metric);
        },
      ),
    ],
  );
});
