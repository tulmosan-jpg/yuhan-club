import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yuhan_club/data/reward_excel.dart';
import 'package:yuhan_club/models/reward.dart';
import 'package:yuhan_club/screens/rewards/redeem_confirm_screen.dart';
import 'package:yuhan_club/widgets/signature_pad.dart';

// 1x1 흰 픽셀 PNG (서명/영수증 자리에 넣는 테스트용 이미지).
const _tinyPngB64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

Coupon _coupon({bool used = true, bool withProof = true}) => Coupon(
      id: 'c1',
      userId: 'u1',
      userName: '김회원',
      drinkId: 'americano',
      drinkName: '아메리카노',
      issuedAt: DateTime(2026, 9, 16, 10, 0),
      used: used,
      usedAt: used ? DateTime(2026, 9, 16, 12, 30) : null,
      signatureB64: withProof ? _tinyPngB64 : null,
      receiptB64: withProof ? _tinyPngB64 : null,
    );

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: child,
    );

void main() {
  group('수령자 명단 엑셀', () {
    test('수령 쿠폰으로 xlsx 를 만들면 유효한 zip 바이트가 나온다', () {
      final bytes = buildRewardRosterXlsx([_coupon(), _coupon()]);
      expect(bytes.length, greaterThan(1000));
      // xlsx = zip: 'PK' 매직 넘버로 시작.
      expect(bytes[0], 0x50);
      expect(bytes[1], 0x4B);
    });

    test('서명/영수증이 없는 행도 깨지지 않는다', () {
      final bytes = buildRewardRosterXlsx([_coupon(withProof: false)]);
      expect(bytes.length, greaterThan(1000));
      expect(utf8.decode(bytes.sublist(0, 2)), 'PK');
    });
  });

  group('수령 확인 화면', () {
    testWidgets('서명·사진 안내가 보이고 완료 버튼은 비활성으로 시작한다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester
          .pumpWidget(_wrap(RedeemConfirmScreen(coupon: _coupon(used: false))));
      await tester.pumpAndSettle();

      expect(find.text('수령 확인'), findsOneWidget);
      expect(find.textContaining('수령자 서명'), findsOneWidget);
      expect(find.textContaining('주문서/영수증 사진'), findsOneWidget);
      expect(find.text('여기에 서명해주세요'), findsOneWidget);
      expect(find.text('김회원 · 아메리카노'), findsOneWidget);

      // 완료 버튼: 서명·사진 전이라 비활성.
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '수령 완료'));
      expect(button.onPressed, isNull);
    });

    testWidgets('서명만 해도 사진이 없으면 완료 버튼이 비활성이다', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester
          .pumpWidget(_wrap(RedeemConfirmScreen(coupon: _coupon(used: false))));
      await tester.pumpAndSettle();

      // 서명 패드에 획을 하나 긋는다.
      final pad = find.byType(SignaturePad);
      await tester.timedDrag(pad, const Offset(60, 20),
          const Duration(milliseconds: 200));
      await tester.pumpAndSettle();

      expect(find.text('여기에 서명해주세요'), findsNothing); // 안내 사라짐
      final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, '수령 완료'));
      expect(button.onPressed, isNull); // 사진이 아직 없다
    });
  });
}
