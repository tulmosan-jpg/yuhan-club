// 스토어용 스크린샷 캡처.
// 실행: flutter test test/store_screenshots_test.dart --dart-define=USE_MOCK=true
// 결과 PNG는 build/screenshots/ 에 저장됨.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:yuhan_club/app/theme.dart';
import 'package:yuhan_club/data/mock_repository.dart';
import 'package:yuhan_club/data/repository.dart';
import 'package:yuhan_club/l10n/locale_provider.dart';
import 'package:yuhan_club/models/attendance.dart';
import 'package:yuhan_club/screens/dashboard/dashboard_screen.dart';
import 'package:yuhan_club/screens/attendance/attendance_screen.dart';
import 'package:yuhan_club/screens/certifications/certifications_screen.dart';
import 'package:yuhan_club/screens/activities/activities_screen.dart';
import 'package:yuhan_club/screens/rewards/reward_section.dart';

Future<void> _loadFonts() async {
  // FontManifest 로 앱 폰트 + MaterialIcons 까지 모두 로드(아이콘 렌더링).
  final manifest = json.decode(
      await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final family in manifest) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List<dynamic>)) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

void main() {
  final repo = MockRepository();
  final captureKey = GlobalKey();

  Widget wrap(Widget child) => MultiProvider(
        providers: [
          Provider<AppRepository>.value(value: repo),
          ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: RepaintBoundary(key: captureKey, child: child),
        ),
      );

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary = captureKey.currentContext!
        .findRenderObject()! as RenderRepaintBoundary;
    // toImage/toByteData 는 반드시 runAsync 안에서(그렇지 않으면 데드락).
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 3.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/screenshots');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File('build/screenshots/$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> shoot(
      WidgetTester tester, String name, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(430, 932)); // ×3 = 1290×2796 (iPhone 6.9")
    await tester.pumpWidget(wrap(screen));
    await tester.pump();
    // 목 저장소 지연(250ms) + 이미지 디코딩 대기. pumpAndSettle 은 무한
    // 애니메이션(스피너/달력)에 걸리므로 사용하지 않는다.
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 900)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await capture(tester, name);
  }

  setUpAll(() async {
    await _loadFonts();
    await repo.joinGroup('g1', '1234'); // 멘토 가입 상태로 화면 채우기
  });

  // 01 홈 대시보드는 별도 처리(테스트 환경에서 일부 위젯 예외) — 생략.

  testWidgets('02 출석', (tester) async {
    await shoot(tester, '02_attendance', const AttendanceScreen());
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('03 리워드', (tester) async {
    // 목 지연 없이 직접 구성(테스트 본문 await 는 fake clock 에서 멈춤).
    final summary = AttendanceSummary(
      currentStreak: 2,
      totalDays: 2,
      checkedInToday: true,
      recentDays: [DateTime(2026, 8, 18)],
    );
    await shoot(
        tester,
        '03_reward',
        Scaffold(
          appBar: AppBar(
              title: const Text('리워드',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: RewardSection(summary: summary),
          ),
        ));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('04 자격증', (tester) async {
    await shoot(tester, '04_certifications', const CertificationsScreen());
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('05 대외활동', (tester) async {
    await shoot(tester, '05_activities', const ActivitiesScreen());
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });
}
