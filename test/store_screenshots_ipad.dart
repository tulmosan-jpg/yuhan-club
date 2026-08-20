// iPad 13" 디스플레이용 스토어 스크린샷 캡처.
// 실행: flutter test test/store_screenshots_ipad.dart --dart-define=USE_MOCK=true
// 결과 PNG는 build/screenshots_ipad/ 에 저장됨 (2048×2732).
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
import 'package:yuhan_club/screens/attendance/attendance_screen.dart';
import 'package:yuhan_club/screens/certifications/certifications_screen.dart';
import 'package:yuhan_club/screens/activities/activities_screen.dart';
import 'package:yuhan_club/screens/rewards/reward_section.dart';

Future<void> _loadFonts() async {
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
    await tester.runAsync(() async {
      // 1024×1366 논리 크기 × 2.0 = 2048×2732 (iPad 13" 규격).
      final image = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = Directory('build/screenshots_ipad');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File('build/screenshots_ipad/$name.png')
          .writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> shoot(
      WidgetTester tester, String name, Widget screen) async {
    await tester.binding.setSurfaceSize(const Size(1024, 1366)); // ×2 = 2048×2732 (iPad 13")
    await tester.pumpWidget(wrap(screen));
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 900)));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await capture(tester, name);
  }

  setUpAll(() async {
    await _loadFonts();
    await repo.joinGroup('g1', '1234');
  });

  testWidgets('02 출석', (tester) async {
    await shoot(tester, '02_attendance', const AttendanceScreen());
    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('03 리워드', (tester) async {
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
