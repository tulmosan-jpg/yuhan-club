import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/repository.dart';
import '../../models/activity.dart';
import '../../app/activity_style.dart';
import '../../l10n/app_strings.dart';
import 'activity_detail_screen.dart';
import 'activity_thumb.dart';

/// 대외활동/박람회 목록 화면 (유한 녹색 브랜드 리디자인).
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  late Future<List<Activity>> _future;
  ActivityType? _filter;
  bool _foodOnly = false;
  bool _pastOnly = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppRepository>().fetchActivities();
  }

  Future<void> _refresh() async {
    final future = context.read<AppRepository>().fetchActivities();
    setState(() => _future = future);
    await future; // 인디케이터가 완료까지 유지되도록 대기
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(context, 'refreshed')),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'activities_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: tr(context, 'refresh'),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                  Center(
                    child: Text(tr(context, 'load_failed'),
                        style: TextStyle(color: Colors.grey.shade600)),
                  ),
                ],
              ),
            );
          }
          var items = snap.data ?? [];
          if (_pastOnly) {
            // 지난 활동: 마감된 것만 (정렬은 repository에서 최근 마감 우선)
            items = items.where((a) => a.closed).toList();
          } else {
            // 그 외 탭: 진행 중(미마감)만 노출
            items = items.where((a) => !a.closed).toList();
            if (_foodOnly) {
              items = items.where((a) => a.foodRelated).toList();
            } else if (_filter != null) {
              items = items.where((a) => a.type == _filter).toList();
            }
          }
          return Column(
            children: [
              _TypeBar(
                selected: _filter,
                foodOnly: _foodOnly,
                pastOnly: _pastOnly,
                onSelected: (t) => setState(() {
                  _filter = t;
                  _foodOnly = false;
                  _pastOnly = false;
                }),
                onFoodSelected: () => setState(() {
                  _foodOnly = true;
                  _filter = null;
                  _pastOnly = false;
                }),
                onPastSelected: () => setState(() {
                  _pastOnly = true;
                  _foodOnly = false;
                  _filter = null;
                }),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: items.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.3),
                            Center(
                              child: Text(
                                  _pastOnly
                                      ? tr(context, 'no_past_activities')
                                      : _foodOnly
                                          ? tr(context, 'no_food_activities')
                                          : tr(context, 'no_activities'),
                                  style: TextStyle(
                                      color: Colors.grey.shade500)),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, i) =>
                              _ActivityCard(activity: items[i]),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TypeBar extends StatelessWidget {
  const _TypeBar({
    required this.selected,
    required this.foodOnly,
    required this.pastOnly,
    required this.onSelected,
    required this.onFoodSelected,
    required this.onPastSelected,
  });
  final ActivityType? selected;
  final bool foodOnly;
  final bool pastOnly;
  final ValueChanged<ActivityType?> onSelected;
  final VoidCallback onFoodSelected;
  final VoidCallback onPastSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _chip(tr(context, 'filter_all'),
              selected == null && !foodOnly && !pastOnly, () => onSelected(null)),
          // 식품영양학과 전용 섹션 — 식품·영양 관련만 모아보기
          _chip(tr(context, 'filter_food'), foodOnly, onFoodSelected,
              accent: true),
          // 지난(마감된) 활동 모아보기
          _chip(tr(context, 'filter_past'), pastOnly, onPastSelected),
          ...ActivityType.values.map(
            (t) => _chip(activityTypeLabel(context, t),
                selected == t && !foodOnly && !pastOnly, () => onSelected(t)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap,
      {bool accent = false}) {
    final Color selBg = accent ? AppTheme.brand600 : AppTheme.brand500;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? selBg
                : (accent ? AppTheme.brandTonal : Colors.white),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? selBg
                  : (accent ? AppTheme.brand200 : const Color(0xFFE4E4E7)),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: selBg.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          // keep-all: 라벨이 잘리지 않도록 고정폭 없이 내용에 맞춰 확장.
          child: Text(
            label,
            softWrap: false,
            overflow: TextOverflow.visible,
            style: TextStyle(
                fontSize: 14,
                fontWeight: (selected || accent)
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: selected
                    ? Colors.white
                    : (accent
                        ? AppTheme.brandOnTonal
                        : const Color(0xFF52525B))),
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ActivityDetailScreen(activity: a),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: const Color(0x0F000000)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ActivityThumb(imageUrl: a.imageUrl, type: a.type, size: 92),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _typeTag(context, a.type),
                        const Spacer(),
                        _dDayBadge(context, a),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(a.title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                            color: Color(0xFF18181B)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    if (a.organizer.isNotEmpty)
                      _metaRow(Icons.apartment_outlined, a.organizer),
                    if (a.deadline != null) ...[
                      const SizedBox(height: 4),
                      _metaRow(
                          Icons.calendar_today_outlined,
                          tr(context, 'due', {
                            'date': DateFormat('yyyy.MM.dd').format(a.deadline!)
                          })),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeTag(BuildContext context, ActivityType type) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.brandTonal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ActivityStyle.icon(type),
              size: 13, color: AppTheme.brandOnTonal),
          const SizedBox(width: 4),
          Text(activityTypeLabel(context, type),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.brandOnTonal)),
        ],
      ),
    );
  }

  Widget _dDayBadge(BuildContext context, Activity a) {
    if (a.closed) {
      return _badge(tr(context, 'closed'), const Color(0xFF9CA3AF),
          const Color(0xFFF4F4F5));
    }
    if (a.deadline == null) return const SizedBox.shrink();
    final days = a.deadline!.difference(DateTime.now()).inDays;
    final dText = days <= 0
        ? tr(context, 'dday_today')
        : tr(context, 'dday', {'n': '$days'});
    if (a.closingSoon) {
      return _badge('$dText · ${tr(context, 'closing_soon')}',
          const Color(0xFFE53E3E), const Color(0xFFFFF0F0));
    }
    return _badge(dText, AppTheme.brand600,
        AppTheme.brand500.withValues(alpha: 0.10));
  }

  Widget _badge(String text, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.bold, color: fg)),
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade400),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
