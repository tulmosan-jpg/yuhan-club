import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../data/repository.dart';
import '../../models/activity.dart';
import '../../app/activity_style.dart';
import 'activity_detail_screen.dart';

/// 대외활동/박람회 목록 화면 (유한 녹색 브랜드 리디자인).
class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  late Future<List<Activity>> _future;
  ActivityType? _filter;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppRepository>().fetchActivities();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('대외활동',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Activity>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('불러오지 못했습니다.',
                  style: TextStyle(color: Colors.grey.shade600)),
            );
          }
          var items = snap.data ?? [];
          if (_filter != null) {
            items = items.where((a) => a.type == _filter).toList();
          }
          return Column(
            children: [
              _TypeBar(
                selected: _filter,
                onSelected: (t) => setState(() => _filter = t),
              ),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text('등록된 활동이 없습니다.',
                            style: TextStyle(color: Colors.grey.shade500)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, i) =>
                            _ActivityCard(activity: items[i]),
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
  const _TypeBar({required this.selected, required this.onSelected});
  final ActivityType? selected;
  final ValueChanged<ActivityType?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          _chip('전체', selected == null, () => onSelected(null)),
          ...ActivityType.values.map(
            (t) => _chip(t.label, selected == t, () => onSelected(t)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.brand500 : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.brand500 : const Color(0xFFE4E4E7),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.brand500.withValues(alpha: 0.25),
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
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF52525B)),
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: const Color(0x0F000000)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _typeTag(a.type),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(a.organizer,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const Spacer(),
                  _dDayBadge(a),
                ],
              ),
              const SizedBox(height: 14),
              Text(a.title,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: Color(0xFF18181B)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 14),
              if (a.deadline != null)
                _metaRow(Icons.calendar_today_outlined,
                    '마감 ${DateFormat('yyyy.MM.dd').format(a.deadline!)}'),
              if (a.location != null) ...[
                const SizedBox(height: 8),
                _metaRow(Icons.place_outlined, a.location!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeTag(ActivityType type) {
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
          Text(type.label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.brandOnTonal)),
        ],
      ),
    );
  }

  Widget _dDayBadge(Activity a) {
    if (a.closed) {
      return _badge('마감', const Color(0xFF9CA3AF), const Color(0xFFF4F4F5));
    }
    if (a.deadline == null) return const SizedBox.shrink();
    final days = a.deadline!.difference(DateTime.now()).inDays;
    final dText = days <= 0 ? 'D-DAY' : 'D-$days';
    if (a.closingSoon) {
      return _badge('$dText 마감임박', const Color(0xFFE53E3E),
          const Color(0xFFFFF0F0));
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
