import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../data/image_util.dart';
import '../../data/repository.dart';
import '../../l10n/app_strings.dart';
import '../../models/group.dart';
import '../../models/report.dart';

/// 보고서 작성/수정 화면. 임시저장 또는 제출.
class ReportEditorScreen extends StatefulWidget {
  const ReportEditorScreen({super.key, this.existing});
  final MentoringReport? existing;

  @override
  State<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends State<ReportEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  ReportRole? _role; // 새 보고서는 미선택(직접 선택 필수)
  late TextEditingController _title;
  late TextEditingController _content;
  late TextEditingController _feedback;
  late TextEditingController _hours;
  late DateTime _date;
  late TimeOfDay _time;
  final List<String> _photos = []; // base64 JPEG, 최대 4장
  bool _saving = false;
  bool _addingPhoto = false;

  List<GroupInfo> _allGroups = []; // 전체 멘토 그룹
  Set<String> _joinedIds = {}; // 내가 가입한 그룹
  bool _groupsLoading = true;
  String? _groupId; // 선택된 그룹

  static const int _maxPhotos = 4;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _role = e?.role; // 기존 보고서는 그 역할, 새 보고서는 미선택
    _title = TextEditingController(text: e?.title ?? '');
    _content = TextEditingController(text: e?.content ?? '');
    _feedback = TextEditingController(text: e?.feedback ?? '');
    _hours =
        TextEditingController(text: e == null ? '' : '${e.activityHours}');
    _date = e?.activityDate ?? DateTime.now();
    _time = TimeOfDay.fromDateTime(e?.activityDate ?? DateTime.now());
    if (e != null) _photos.addAll(e.photos);
    _groupId = e?.groupId;
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    final repo = context.read<AppRepository>();
    // 1) 전체 그룹 목록 먼저 로드 → 로딩 종료(드롭다운 표시).
    try {
      final all = await repo.fetchGroupIndex();
      if (mounted) {
        setState(() {
          _allGroups = all;
          _groupsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _groupsLoading = false);
    }
    // 2) 내 가입 그룹은 별도로(실패해도 무방).
    try {
      final mine = await repo.fetchMyGroups();
      if (mounted) {
        setState(() {
          _joinedIds = mine.map((g) => g.id).toSet();
          if (_groupId == null && mine.length == 1) _groupId = mine.first.id;
        });
      }
    } catch (_) {}
  }

  /// 드롭다운에서 그룹 선택. 미가입이면 PIN 입력받아 참여.
  Future<void> _selectGroup(String gid) async {
    if (_joinedIds.contains(gid)) {
      setState(() => _groupId = gid);
      return;
    }
    final pinCtrl = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text(tr(context, 'enter_pin')),
        content: TextField(
          controller: pinCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: tr(context, 'group_pin')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: Text(tr(context, 'cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, pinCtrl.text),
              child: Text(tr(context, 'join_group'))),
        ],
      ),
    );
    if (entered == null || !mounted) return;
    final ok = await context.read<AppRepository>().joinGroup(gid, entered);
    if (!mounted) return;
    if (ok) {
      setState(() {
        _joinedIds.add(gid);
        _groupId = gid;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'join_success'))));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'join_failed'))));
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= _maxPhotos || _addingPhoto) return;
    setState(() => _addingPhoto = true);
    try {
      final b64 = await pickResizedPhotoBase64();
      if (b64 != null && mounted) setState(() => _photos.add(b64));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(context, 'photo_pick_failed'))));
      }
    } finally {
      if (mounted) setState(() => _addingPhoto = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _feedback.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save(ReportStatus status) async {
    if (!_formKey.currentState!.validate()) return;
    if (_role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'select_role_first'))));
      return;
    }
    if (_groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'no_group_join_first'))));
      return;
    }
    setState(() => _saving = true);
    final repo = context.read<AppRepository>();
    final report = MentoringReport(
      id: widget.existing?.id ?? '',
      role: _role!,
      authorName: repo.currentUserName,
      partnerName: '', // 그룹으로 상대(멘토) 특정 → 별도 입력 없음
      activityDate: DateTime(
        _date.year,
        _date.month,
        _date.day,
        _time.hour,
        _time.minute,
      ),
      activityHours: int.tryParse(_hours.text.trim()) ?? 0,
      title: _title.text.trim(),
      content: _content.text.trim(),
      feedback: _feedback.text.trim().isEmpty
          ? null
          : _feedback.text.trim(),
      photos: List.of(_photos),
      groupId: _groupId,
      status: status,
      updatedAt: DateTime.now(),
    );
    try {
      await repo.saveReport(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == ReportStatus.submitted
              ? tr(context, 'submitted_msg')
              : tr(context, 'saved_draft_msg')),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'save_failed', {'e': '$e'}))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              tr(context, _isEdit ? 'report_edit_title' : 'report_new_title'),
              style: const TextStyle(fontWeight: FontWeight.bold))),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(tr(context, 'report_author_role'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<ReportRole>(
              emptySelectionAllowed: true,
              segments: [
                ButtonSegment(
                    value: ReportRole.mentor,
                    label: Text(tr(context, 'role_mentor'))),
                ButtonSegment(
                    value: ReportRole.mentee,
                    label: Text(tr(context, 'role_mentee'))),
              ],
              selected: _role == null ? <ReportRole>{} : {_role!},
              onSelectionChanged: (s) =>
                  setState(() => _role = s.isEmpty ? null : s.first),
            ),
            const SizedBox(height: 16),

            // ── 그룹(멘토) 선택 ── 미가입 그룹은 선택 시 PIN 입력.
            Text(tr(context, 'select_mentor'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (_groupsLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_allGroups.isEmpty)
              Text(tr(context, 'no_groups'),
                  style: TextStyle(color: Colors.grey.shade500))
            else
              DropdownButtonFormField<String>(
                key: ValueKey(_groupId), // 값 변경 시 표시 갱신
                initialValue:
                    _allGroups.any((g) => g.id == _groupId) ? _groupId : null,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr(context, 'select_group'),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _allGroups
                    .map((g) => DropdownMenuItem(
                          value: g.id,
                          child: Row(
                            children: [
                              Flexible(
                                  child: Text(g.name,
                                      overflow: TextOverflow.ellipsis)),
                              if (!_joinedIds.contains(g.id)) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.lock_outline,
                                    size: 14, color: Color(0xFF9CA3AF)),
                              ],
                            ],
                          ),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) _selectGroup(v);
                },
              ),
            const SizedBox(height: 16),
            // 상대방 이름 칸 제거 — 그룹(멘토 팀) 선택으로 멘토가 특정됨.
            _field(_title, tr(context, 'report_title_field'), required: true),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: tr(context, 'report_date'),
                        isDense: true,
                        suffixIcon: const Icon(
                            Icons.calendar_today_outlined, size: 18),
                      ),
                      child: Text(
                        DateFormat('yyyy.MM.dd').format(_date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: tr(context, 'report_time'),
                        isDense: true,
                        suffixIcon: const Icon(Icons.access_time, size: 18),
                      ),
                      child: Text(
                        _time.format(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _field(_hours, tr(context, 'report_hours'),
                keyboard: TextInputType.number, required: true),
            _field(_content, tr(context, 'report_content'),
                required: true, maxLines: 6),
            _field(_feedback, tr(context, 'report_feedback_field'),
                required: true, maxLines: 4),
            const SizedBox(height: 8),

            // ── 사진 첨부 (최대 4장) ──
            Text(tr(context, 'report_photos'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            _PhotoPicker(
              photos: _photos,
              maxPhotos: _maxPhotos,
              adding: _addingPhoto,
              onAdd: _addPhoto,
              onRemove: (i) => setState(() => _photos.removeAt(i)),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => _save(ReportStatus.draft),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: Text(tr(context, 'save_draft')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : () => _save(ReportStatus.submitted),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(tr(context, 'submit')),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboard,
    double bottomPadding = 14,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          alignLabelWithHint: true,
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty)
                ? tr(context, 'field_required', {'label': label})
                : null
            : null,
      ),
    );
  }
}

/// 사진 썸네일 그리드 + 추가 버튼(최대 [maxPhotos]장).
class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photos,
    required this.maxPhotos,
    required this.adding,
    required this.onAdd,
    required this.onRemove,
  });
  final List<String> photos;
  final int maxPhotos;
  final bool adding;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (int i = 0; i < photos.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(photos[i]),
                  width: 84,
                  height: 84,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(Icons.close,
                        size: 15, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        if (photos.length < maxPhotos)
          GestureDetector(
            onTap: adding ? null : onAdd,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E4E7)),
              ),
              child: adding
                  ? const Center(
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            size: 22, color: Colors.grey.shade500),
                        const SizedBox(height: 4),
                        Text('${photos.length}/$maxPhotos',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade500)),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}
