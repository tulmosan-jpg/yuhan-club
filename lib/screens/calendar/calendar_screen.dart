import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../app/theme.dart';
import '../../data/repository.dart';
import '../../l10n/app_strings.dart';
import '../../models/attendance.dart';

/// 통합 일정: 출석일 + 출석 완료 + 대외활동 마감을 한 달력에.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalEvent {
  final String label;
  final Color color;
  const _CalEvent(this.label, this.color);
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = AttendanceRecord.dayOf(DateTime.now());
  bool _loading = true;

  final Map<DateTime, List<_CalEvent>> _events = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<AppRepository>();
    // 라벨은 await 전에 캡처(async gap에서 context 미사용).
    final lblSession = tr(context, 'cal_attendance');
    final lblAttended = tr(context, 'cal_attended');
    final deadlineTmpl = tr(context, 'cal_deadline', {'title': ''});
    try {
      final groups = await repo.fetchMyGroups();
      List<DateTime> dates = [];
      Set<DateTime> attended = {};
      if (groups.isNotEmpty) {
        final gid = groups.first.id;
        dates = await repo.fetchGroupAttendanceDates(gid);
        final summary = await repo.fetchMyGroupAttendance(gid);
        attended = summary.recentDays.map(AttendanceRecord.dayOf).toSet();
      }
      final activities = await repo.fetchActivities();

      final map = <DateTime, List<_CalEvent>>{};
      void add(DateTime day, _CalEvent e) =>
          (map[AttendanceRecord.dayOf(day)] ??= []).add(e);

      for (final d in dates) {
        final done = attended.contains(AttendanceRecord.dayOf(d));
        add(
            d,
            _CalEvent(done ? lblAttended : lblSession,
                done ? AppTheme.brand600 : AppTheme.brand400));
      }
      for (final a in activities) {
        if (a.deadline == null) continue;
        // deadlineTmpl = "{title} 마감"에 빈 제목 → " 마감"/" deadline".
        add(a.deadline!,
            _CalEvent('${a.title}$deadlineTmpl', const Color(0xFFE53E3E)));
      }
      if (mounted) {
        setState(() {
          _events
            ..clear()
            ..addAll(map);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_CalEvent> _eventsOf(DateTime day) =>
      _events[AttendanceRecord.dayOf(day)] ?? const [];

  @override
  Widget build(BuildContext context) {
    final selectedEvents = _eventsOf(_selected);
    return Scaffold(
      appBar: AppBar(
          title: Text(tr(context, 'calendar_title'),
              style: const TextStyle(fontWeight: FontWeight.bold))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                    child: TableCalendar<_CalEvent>(
                      locale: 'ko_KR',
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2100, 12, 31),
                      focusedDay: _focused,
                      selectedDayPredicate: (d) =>
                          AttendanceRecord.dayOf(d) == _selected,
                      eventLoader: _eventsOf,
                      onDaySelected: (sel, foc) => setState(() {
                        _selected = AttendanceRecord.dayOf(sel);
                        _focused = foc;
                      }),
                      onPageChanged: (d) => _focused = d,
                      availableGestures: AvailableGestures.horizontalSwipe,
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(fontFamily: 'Pretendard'),
                        weekendStyle: TextStyle(fontFamily: 'Pretendard'),
                      ),
                      calendarStyle: CalendarStyle(
                        defaultTextStyle:
                            const TextStyle(fontFamily: 'Pretendard'),
                        weekendTextStyle:
                            const TextStyle(fontFamily: 'Pretendard'),
                        outsideTextStyle: const TextStyle(
                            fontFamily: 'Pretendard', color: Color(0xFFBDBDBD)),
                        selectedDecoration: const BoxDecoration(
                            color: AppTheme.brand500, shape: BoxShape.circle),
                        todayDecoration: BoxDecoration(
                            color: AppTheme.brand500.withValues(alpha: 0.25),
                            shape: BoxShape.circle),
                      ),
                      calendarBuilders: CalendarBuilders(
                        markerBuilder: (context, day, events) {
                          if (events.isEmpty) return null;
                          return Positioned(
                            bottom: 4,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: events.take(3).map((e) {
                                return Container(
                                  width: 5,
                                  height: 5,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                      color: e.color, shape: BoxShape.circle),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _legend(context),
                const SizedBox(height: 12),
                Text(DateFormat('yyyy년 M월 d일 (E)', 'ko').format(_selected),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (selectedEvents.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(tr(context, 'cal_no_events'),
                          style: TextStyle(color: Colors.grey.shade500)),
                    ),
                  )
                else
                  ...selectedEvents.map((e) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x0F000000)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: e.color, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(e.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
    );
  }

  Widget _legend(BuildContext context) {
    Widget dot(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(t,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(AppTheme.brand400, tr(context, 'legend_session')),
        const SizedBox(width: 16),
        dot(const Color(0xFFE53E3E), tr(context, 'legend_deadline')),
      ],
    );
  }
}
