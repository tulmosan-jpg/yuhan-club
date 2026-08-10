import 'package:flutter_test/flutter_test.dart';

import 'package:yuhan_club/main.dart';

void main() {
  testWidgets('앱이 정상적으로 뜨고 홈 탭이 보인다', (WidgetTester tester) async {
    await tester.pumpWidget(const YuhanFnApp());
    await tester.pump(const Duration(milliseconds: 400));

    // 하단 네비게이션 탭 라벨 확인
    expect(find.text('보고서'), findsWidgets);
    expect(find.text('출석'), findsWidgets);
  });
}
