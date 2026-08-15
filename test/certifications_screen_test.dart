import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yuhan_club/screens/certifications/certifications_screen.dart';

Widget _wrap() => const MaterialApp(
      locale: Locale('ko'),
      supportedLocales: [Locale('ko'), Locale('en')],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: CertificationsScreen(),
    );

void main() {
  testWidgets('자격증 목록에 면허/기술자격 항목이 표시된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('영양사'), findsOneWidget);
    expect(find.text('위생사'), findsOneWidget);
    expect(find.text('식품기사'), findsOneWidget);
    expect(find.text('스포츠 영양코치 (SNC)'), findsOneWidget);
    expect(find.text('면허 (국시원)'), findsOneWidget);
    expect(find.text('국가기술자격 (큐넷)'), findsOneWidget);
    expect(find.text('민간자격'), findsOneWidget);
  });

  testWidgets('항목을 누르면 상세(응시자격/시험과목)로 이동한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(500, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('영양사'));
    await tester.pumpAndSettle();

    expect(find.text('응시자격'), findsOneWidget);
    expect(find.text('시험과목'), findsOneWidget);
    expect(find.text('공식 사이트에서 확인'), findsOneWidget);
  });
}
