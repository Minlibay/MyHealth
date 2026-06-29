import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers.dart';

class _Slide {
  const _Slide(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
}

const _slides = [
  _Slide(
    Icons.favorite_rounded,
    'Добро пожаловать в MyHealth',
    'Все показатели вашего здоровья — в одном красивом и понятном месте.',
  ),
  _Slide(
    Icons.devices_rounded,
    'Данные с ваших устройств',
    'Приложение считывает показатели из Apple Health и Google Health '
        'Connect — часы, тонометры, весы и глюкометры.',
  ),
  _Slide(
    Icons.lock_rounded,
    'Приватность прежде всего',
    'Данные остаются только на вашем телефоне. Ничего не отправляется '
        'в облако и не покидает устройство.',
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _page == _slides.length - 1;

  void _finish() => ref.read(onboardingControllerProvider.notifier).complete();

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Пропустить'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  child: Text(_isLast ? 'Начать' : 'Далее'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  Color.lerp(theme.colorScheme.primary, Colors.black, 0.2)!,
                ],
              ),
              borderRadius: BorderRadius.circular(36),
            ),
            child: Icon(slide.icon, size: 60, color: Colors.white),
          ),
          const SizedBox(height: 40),
          Text(slide.title,
              style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 14),
          Text(
            slide.text,
            style: theme.textTheme.bodyLarge
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
