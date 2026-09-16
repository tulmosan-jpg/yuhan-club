import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import 'theme.dart';

/// 앱 진입 인트로 모션.
///
/// 엠블럼이 옅은 포인트색 원과 함께 떠오르고, 이어서 학과명이 올라온다.
/// 끝나면 [onDone] 으로 본 화면(AuthGate)에 넘긴다.
///
/// DESIGN.md 규칙: 진입 애니메이션은 600ms 이내, 한 방향으로,
/// 접근성 '모션 줄이기'가 켜져 있으면 건너뛴다.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  // 엠블럼: 살짝 커지며 나타난다.
  late final Animation<double> _emblemFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );
  late final Animation<double> _emblemScale = Tween(begin: 0.88, end: 1.0)
      .animate(CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
  ));

  // 원형 배경: 엠블럼보다 조금 먼저 퍼진다.
  late final Animation<double> _haloScale = Tween(begin: 0.6, end: 1.0)
      .animate(CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.5, curve: Curves.easeOutCubic),
  ));

  // 학과명: 엠블럼이 자리잡은 뒤 아래에서 올라온다.
  late final Animation<double> _titleFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.4, 1, curve: Curves.easeOut),
  );
  late final Animation<Offset> _titleSlide =
      Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(0.4, 1, curve: Curves.easeOutCubic),
    ),
  );

  bool _handedOff = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 모션 줄이기가 켜져 있으면 인트로를 건너뛴다.
    if (MediaQuery.of(context).disableAnimations) {
      _finish();
    } else if (!_c.isAnimating && _c.value == 0) {
      _c.forward();
    }
  }

  void _finish() {
    if (_handedOff) return;
    _handedOff = true;
    // 마지막 프레임이 그려진 뒤에 넘긴다(전환이 끊겨 보이지 않게).
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onDone());
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) => FadeTransition(
                opacity: _emblemFade,
                child: Transform.scale(
                  scale: _haloScale.value,
                  child: Container(
                    width: 128,
                    height: 128,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppTheme.brandTonal,
                      shape: BoxShape.circle,
                    ),
                    child: Transform.scale(
                      scale: _emblemScale.value,
                      child: child,
                    ),
                  ),
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/yuhan_emblem.png',
                  width: 96,
                  height: 96,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.eco,
                    size: 56,
                    color: AppTheme.brand500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            FadeTransition(
              opacity: _titleFade,
              child: SlideTransition(
                position: _titleSlide,
                child: Text(
                  tr(context, 'app_title'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: AppTheme.brand900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
