import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;

import '../models/reward.dart';

// 시트 색: 앱 브랜드 토큰(DESIGN.md)과 동일 계열.
const String _brand = '#1F9D6B'; // 헤더 배경
const String _brandDark = '#114033'; // 제목 글자
const String _border = '#E4E4E7'; // 표 테두리
const String _muted = '#6B7280'; // 부가 정보

/// 수령 완료 쿠폰 목록을 "수령자 명단" 엑셀(xlsx) 바이트로 만든다.
///
/// 구성: 제목 + 생성 정보 → 브랜드 그린 헤더 행 →
/// 행마다 번호·수령자·음료·수령 일시·서명 이미지·주문서/영수증 이미지.
Uint8List buildRewardRosterXlsx(List<Coupon> usedCoupons) {
  final workbook = xlsio.Workbook();
  final sheet = workbook.worksheets[0];
  sheet.name = '수령자 명단';
  sheet.showGridlines = false;

  // ── 열 너비(문자 수 단위) ──
  sheet.getRangeByName('A1').columnWidth = 6; // 번호
  sheet.getRangeByName('B1').columnWidth = 14; // 수령자
  sheet.getRangeByName('C1').columnWidth = 18; // 음료
  sheet.getRangeByName('D1').columnWidth = 20; // 수령 일시
  sheet.getRangeByName('E1').columnWidth = 24; // 서명
  sheet.getRangeByName('F1').columnWidth = 20; // 주문서/영수증

  // ── 제목 ──
  final title = sheet.getRangeByName('A1:F1')..merge();
  title.setText('빽다방 리워드 수령자 명단');
  title.cellStyle
    ..fontSize = 16
    ..bold = true
    ..fontColor = _brandDark
    ..hAlign = xlsio.HAlignType.left
    ..vAlign = xlsio.VAlignType.center;
  sheet.getRangeByName('A1').rowHeight = 30;

  final info = sheet.getRangeByName('A2:F2')..merge();
  info.setText(
      '생성 ${DateFormat('yyyy.MM.dd HH:mm').format(DateTime.now())} · 총 ${usedCoupons.length}건 · 유한대 식품영양학과');
  info.cellStyle
    ..fontSize = 10
    ..fontColor = _muted
    ..hAlign = xlsio.HAlignType.left
    ..vAlign = xlsio.VAlignType.center;
  sheet.getRangeByName('A2').rowHeight = 16;
  sheet.getRangeByName('A3').rowHeight = 8; // 여백 행

  // ── 헤더 행 ──
  const headerRow = 4;
  const headers = ['번호', '수령자', '음료', '수령 일시', '서명', '주문서/영수증'];
  for (var i = 0; i < headers.length; i++) {
    final cell = sheet.getRangeByIndex(headerRow, i + 1);
    cell.setText(headers[i]);
    cell.cellStyle
      ..backColor = _brand
      ..fontColor = '#FFFFFF'
      ..bold = true
      ..fontSize = 11
      ..hAlign = xlsio.HAlignType.center
      ..vAlign = xlsio.VAlignType.center;
  }
  sheet.getRangeByIndex(headerRow, 1).rowHeight = 22;

  // ── 데이터 행 ──
  final fmt = DateFormat('yyyy.MM.dd HH:mm');
  for (var i = 0; i < usedCoupons.length; i++) {
    final c = usedCoupons[i];
    final r = headerRow + 1 + i;
    sheet.getRangeByIndex(r, 1)
      ..setNumber((i + 1).toDouble())
      ..numberFormat = '0';
    sheet.getRangeByIndex(r, 2).setText(c.userName);
    sheet.getRangeByIndex(r, 3).setText(c.drinkName);
    sheet
        .getRangeByIndex(r, 4)
        .setText(c.usedAt != null ? fmt.format(c.usedAt!) : '-');

    // 이미지가 들어갈 행이라 높이를 키운다(포인트 단위, ≈75px).
    sheet.getRangeByIndex(r, 1).rowHeight = 56;

    // 서명(PNG base64) — 5열.
    final sig = c.signatureB64;
    if (sig != null && sig.isNotEmpty) {
      final pic = sheet.pictures.addBase64(r, 5, sig);
      pic
        ..width = 150
        ..height = 66;
    } else {
      sheet.getRangeByIndex(r, 5).setText('-');
    }
    // 주문서/영수증(JPEG base64) — 6열.
    final rc = c.receiptB64;
    if (rc != null && rc.isNotEmpty) {
      final pic = sheet.pictures.addBase64(r, 6, rc);
      pic
        ..width = 100
        ..height = 70;
    } else {
      sheet.getRangeByIndex(r, 6).setText('-');
    }

    // 셀 공통 스타일: 가운데 정렬 + 옅은 테두리.
    for (var col = 1; col <= 6; col++) {
      final cell = sheet.getRangeByIndex(r, col);
      cell.cellStyle
        ..fontSize = 11
        ..hAlign =
            col == 2 || col == 3 ? xlsio.HAlignType.left : xlsio.HAlignType.center
        ..vAlign = xlsio.VAlignType.center
        ..borders.all.lineStyle = xlsio.LineStyle.thin
        ..borders.all.color = _border;
    }
  }

  // 헤더 행에도 테두리(데이터와 이어지게).
  for (var col = 1; col <= 6; col++) {
    sheet.getRangeByIndex(headerRow, col).cellStyle.borders.all
      ..lineStyle = xlsio.LineStyle.thin
      ..color = _brand;
  }

  final bytes = Uint8List.fromList(workbook.saveAsStream());
  workbook.dispose();
  return bytes;
}
