import 'package:flutter_test/flutter_test.dart';
import 'package:yuhan_club/data/attendance_logic.dart';
import 'package:yuhan_club/models/attendance.dart';

void main() {
  DateTime day(int offsetDays) =>
      AttendanceRecord.dayOf(DateTime.now().add(Duration(days: offsetDays)));

  group('스케줄 기준 연속 출석', () {
    test('주 단위 모임을 연속 출석하면 streak가 누적된다', () {
      // 예정일: 2주 전, 1주 전, 오늘. 지난 두 모임 모두 출석, 오늘은 아직.
      final schedule = [day(-14), day(-7), day(0)];
      final attended = [day(-14), day(-7)];
      final s = AttendanceLogic.summarize(attended, schedule: schedule);
      expect(s.currentStreak, 2); // 하루 간격이 아니어도 연속 2회로 집계
      expect(s.checkedInToday, false);
    });

    test('오늘 출석하면 오늘 모임까지 포함해 streak가 늘어난다', () {
      final schedule = [day(-14), day(-7), day(0)];
      final attended = [day(-14), day(-7), day(0)];
      final s = AttendanceLogic.summarize(attended, schedule: schedule);
      expect(s.currentStreak, 3);
      expect(s.checkedInToday, true);
    });

    test('중간 모임을 빠지면 streak가 끊긴다', () {
      final schedule = [day(-14), day(-7), day(0)];
      final attended = [day(-14), day(0)]; // 1주 전 결석
      final s = AttendanceLogic.summarize(attended, schedule: schedule);
      expect(s.currentStreak, 1); // 오늘부터 다시 1
    });

    test('오늘이 예정일이지만 아직 미출석이면 결석으로 치지 않는다', () {
      final schedule = [day(-7), day(0)];
      final attended = [day(-7)];
      final s = AttendanceLogic.summarize(attended, schedule: schedule);
      expect(s.currentStreak, 1); // 오늘 모임은 진행 중이므로 이전 streak 유지
    });

    test('가장 최근 지난 예정일을 빠지면 과거 출석이 있어도 streak=0', () {
      final schedule = [day(-14), day(-7), day(0)];
      final attended = [day(-14)]; // 1주 전(가장 최근 지난 예정일) 결석
      final s = AttendanceLogic.summarize(attended, schedule: schedule);
      expect(s.currentStreak, 0);
    });

    test('예정일이 아닌 날 출석은 streak에 반영되지 않는다', () {
      final schedule = [day(-7), day(0)];
      // 예정일(-7)엔 결석, 엉뚱한 날(-3)에만 출석 기록
      final attended = [day(-3)];
      final s = AttendanceLogic.summarize(attended, schedule: schedule);
      expect(s.currentStreak, 0);
    });

    test('커피 보상 기준(연속 2회) 도달 확인', () {
      final schedule = [day(-7), day(0)];
      final attended = [day(-7), day(0)];
      final s = AttendanceLogic.summarize(attended, schedule: schedule);
      expect(s.currentStreak >= AttendanceLogic.coffeeStreak, true);
    });
  });

  test('스케줄 미지정 시 달력상 연속일 기준(하위호환)', () {
    final attended = [day(-2), day(-1), day(0)];
    final s = AttendanceLogic.summarize(attended);
    expect(s.currentStreak, 3);
  });
}
