import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yuhan_club/l10n/app_strings.dart';

void main() {
  testWidgets('언어(ko/en)에 따라 번역 문자열이 바뀐다', (WidgetTester tester) async {
    Future<void> pumpWith(Locale locale) async {
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('ko'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Text(tr(context, 'nav_home')),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await pumpWith(const Locale('ko'));
    expect(find.text('홈'), findsOneWidget);

    await pumpWith(const Locale('en'));
    expect(find.text('Home'), findsOneWidget);
  });
}
