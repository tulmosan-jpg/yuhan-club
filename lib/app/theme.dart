import 'package:flutter/material.dart';

/// 유한대학교 식품영양학과 브랜드 테마 — 엠블럼 teal-green 계열.
/// AIDesigner 시안 토큰을 반영: brand green scale + M3 tonal surface.
class AppTheme {
  // ── Brand green scale (엠블럼 녹색 계열) ──────────────────────────
  static const Color brand50 = Color(0xFFF0FDF6);
  static const Color brand100 = Color(0xFFDBFCE9);
  static const Color brand200 = Color(0xFFBCF6D6);
  static const Color brand300 = Color(0xFF89EBBE);
  static const Color brand400 = Color(0xFF4FD69F);
  static const Color brand500 = Color(0xFF1F9D6B); // Base Primary
  static const Color brand600 = Color(0xFF17795A); // Darker
  static const Color brand700 = Color(0xFF15614A);
  static const Color brand800 = Color(0xFF134E3D);
  static const Color brand900 = Color(0xFF114033);

  /// M3 tonal surface (연한 녹색 배경) + 그 위 텍스트.
  static const Color brandTonal = Color(0xFFE0F5EB);
  static const Color brandOnTonal = Color(0xFF0E5C3D);

  static const Color primary = brand500;
  static const Color accent = brand600;

  /// 앱 전체 배경 (거의 흰색, 아주 옅은 그레이).
  static const Color scaffoldBg = Color(0xFFFAFAFA);

  // ── Semantic / accent (시안 리스트 태그 색) ───────────────────────
  static const Color streakFlame = Color(0xFFFDE047); // 노랑(리워드/불꽃)
  static const Color tagBlue = Color(0xFF2563EB);
  static const Color tagPurple = Color(0xFF9333EA);

  // ── Shape tokens ─────────────────────────────────────────────────
  static const double radiusCard = 24; // rounded-3xl 느낌
  static const double radiusField = 14;
  static const double radiusPill = 999;

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: brand500,
      primary: brand500,
      secondary: brand600,
      surfaceTint: brand500,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: scaffoldBg,
      // Pretendard 번들 완료(assets/fonts). 시안과 동일 폰트로 렌더링.
      fontFamily: 'Pretendard',
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: Color(0xFF18181B), // zinc-900
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: const BorderSide(color: Color(0x14000000)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        backgroundColor: brandTonal,
        selectedColor: brand500,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusPill),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: brandTonal,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? brandOnTonal : const Color(0xFF71717A),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? brandOnTonal : const Color(0xFF71717A),
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: const BorderSide(color: Color(0xFFE4E4E7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: const BorderSide(color: brand500, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brand500,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusField),
          ),
        ),
      ),
    );
  }
}
