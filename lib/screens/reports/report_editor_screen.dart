import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../data/image_util.dart';
import '../../data/repository.dart';
import '../../l10n/app_strings.dart';
import '../../models/report.dart';

// 새 보고서 작성/수정 화면 디자인 토큰.
const Color _pageBg = Color(0xFFF6F7F9);
const Color _fieldBg = Color(0xFFF1F2F4);
const Color _hint = Color(0xFF9CA3AF);
const Color _labelColor = Color(0xFF1F2430);
const Color _icon = Color(0xFF9AA1AD);

const List<String> _weekdaysKo = ['월', '화', '수', '목', '금', '토', '일'];
String _weekdayKo(int weekday) => _weekdaysKo[(weekday - 1) % 7];

/// 보고서 작성/수정 화면. 임시저장 또는 제출.
class ReportEditorScreen extends StatefulWidget {
  const ReportEditorScreen({super.key, this.existing, this.groupId});
  final MentoringReport? existing;

  /// 작성자의 멘토(그룹) id. 호출부에서 넘겨 재조회를 없앤다.
  final String? groupId;

  @override
  State<ReportEditorScreen> createState() => _ReportEditorScreenState();
}

class _ReportEditorScreenState extends State<ReportEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  ReportRole? _role; // 새 보고서는 미선택(직접 선택 필수)
  late TextEditingController _name;
  late TextEditingController _title;
  late TextEditingController _content;
  late TextEditingController _feedback;
  late DateTime _date;
  int _hours = 2; // 활동 시간(소요 시간, 드롭다운)
  final List<String> _photos = []; // base64 JPEG, 최대 4장
  bool _saving = false;
  bool _addingPhoto = false;

  // 멘토(그룹)는 출석 탭에서 미리 선택 → 여기선 내 멘토를 자동 사용.
  String? _groupId; // 내 멘토(그룹)

  static const int _maxPhotos = 4;
  static const List<int> _hourOptions = [1, 2, 3, 4, 5, 6, 7, 8];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _role = e?.role; // 기존 보고서는 그 역할, 새 보고서는 미선택
    _name = TextEditingController(text: e?.authorName ?? '');
    _title = TextEditingController(text: e?.title ?? '');
    _content = TextEditingController(text: e?.content ?? '');
    _feedback = TextEditingController(text: e?.feedback ?? '');
    _date = e?.activityDate ?? DateTime.now();
    if (e != null && e.activityHours > 0) _hours = e.activityHours;
    if (e != null) _photos.addAll(e.photos);
    // 멘토(그룹)는 호출부에서 전달받아 사용(재조회 없음).
    _groupId = e?.groupId ?? widget.groupId;
  }

  bool _prefilled = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 새 보고서면 본인 이름을 계정명으로 미리 채운다(수정 가능).
    if (!_prefilled && !_isEdit && _name.text.isEmpty) {
      _name.text = context.read<AppRepository>().currentUserName;
    }
    _prefilled = true;
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
    _name.dispose();
    _title.dispose();
    _content.dispose();
    _feedback.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    FocusScope.of(context).unfocus();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickHours() async {
    FocusScope.of(context).unfocus();
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE4E4E7),
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(tr(context, 'report_hours'),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              for (final h in _hourOptions)
                ListTile(
                  title: Text(tr(context, 'hours_n_label', {'n': '$h'})),
                  trailing: h == _hours
                      ? const Icon(Icons.check, color: Color(0xFF102A6B))
                      : null,
                  onTap: () => Navigator.pop(context, h),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) setState(() => _hours = picked);
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
      authorName: _name.text.trim().isEmpty
          ? repo.currentUserName
          : _name.text.trim(),
      partnerName: '',
      activityDate:
          DateTime(_date.year, _date.month, _date.day),
      activityHours: _hours,
      title: _title.text.trim(),
      content: _content.text.trim(),
      feedback:
          _feedback.text.trim().isEmpty ? null : _feedback.text.trim(),
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
      backgroundColor: _pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1F2430)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          tr(context, _isEdit ? 'report_edit_title' : 'report_new_title'),
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Color(0xFF1F2430)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            // ── 나의 역할 ──
            _label(tr(context, 'report_author_role')),
            const SizedBox(height: 10),
            _RoleToggle(
              role: _role,
              onChanged: (r) => setState(() => _role = r),
            ),
            const SizedBox(height: 22),

            // ── 이름(본인) ──
            _label(tr(context, 'report_name_label'), required: true),
            const SizedBox(height: 10),
            _FilledInput(
              controller: _name,
              hint: tr(context, 'report_name_hint'),
              validator: _requiredValidator(tr(context, 'report_name_label')),
            ),
            const SizedBox(height: 22),

            // ── 활동 날짜 / 활동 시간 ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(tr(context, 'report_date')),
                      const SizedBox(height: 10),
                      _TapBox(
                        icon: Icons.calendar_today_outlined,
                        text:
                            '${DateFormat('yyyy.MM.dd').format(_date)} (${_weekdayKo(_date.weekday)})',
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(tr(context, 'report_time')),
                      const SizedBox(height: 10),
                      _TapBox(
                        icon: Icons.access_time,
                        text: tr(context, 'hours_n_label', {'n': '$_hours'}),
                        trailing: Icons.keyboard_arrow_down,
                        onTap: _pickHours,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── 제목 ──
            _label(tr(context, 'report_title_field')),
            const SizedBox(height: 10),
            _FilledInput(
              controller: _title,
              hint: tr(context, 'report_title_hint'),
              validator: _requiredValidator(tr(context, 'report_title_field')),
            ),
            const SizedBox(height: 22),

            // ── 활동 내용 ──
            _label(tr(context, 'report_content')),
            const SizedBox(height: 10),
            _FilledInput(
              controller: _content,
              hint: tr(context, 'report_content_hint'),
              minLines: 5,
              maxLines: 8,
              validator: _requiredValidator(tr(context, 'report_content')),
            ),
            const SizedBox(height: 22),

            // ── 소감/피드백 ──
            _label(tr(context, 'report_feedback_field')),
            const SizedBox(height: 10),
            _FilledInput(
              controller: _feedback,
              hint: tr(context, 'report_feedback_hint'),
              minLines: 3,
              maxLines: 6,
              validator:
                  _requiredValidator(tr(context, 'report_feedback_field')),
            ),
            const SizedBox(height: 22),

            // ── 사진 첨부 (최대 4장) ──
            _label(tr(context, 'report_photos')),
            const SizedBox(height: 10),
            _PhotoPicker(
              photos: _photos,
              maxPhotos: _maxPhotos,
              adding: _addingPhoto,
              onAdd: _addPhoto,
              onRemove: (i) => setState(() => _photos.removeAt(i)),
            ),
            const SizedBox(height: 28),

            // ── 액션 버튼 ──
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => _save(ReportStatus.draft),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        side: const BorderSide(color: Color(0xFFD8DBE0)),
                        foregroundColor: const Color(0xFF52525B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text(tr(context, 'save_draft'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving
                        ? null
                        : () => _save(ReportStatus.submitted),
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Text(tr(context, 'submit'),
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? Function(String?) _requiredValidator(String label) =>
      (v) => (v == null || v.trim().isEmpty)
          ? tr(context, 'field_required', {'label': label})
          : null;

  Widget _label(String text, {bool required = false}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _labelColor)),
        const Spacer(),
        if (required)
          Text(tr(context, 'required_tag'),
              style: const TextStyle(fontSize: 12, color: _hint)),
      ],
    );
  }
}

/// 멘토/멘티 pill 토글.
class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.role, required this.onChanged});
  final ReportRole? role;
  final ValueChanged<ReportRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFEBEDF1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _seg(context, ReportRole.mentor,
              '${tr(context, 'role_mentor')} (Mentor)'),
          _seg(context, ReportRole.mentee,
              '${tr(context, 'role_mentee')} (Mentee)'),
        ],
      ),
    );
  }

  Widget _seg(BuildContext context, ReportRole value, String text) {
    final selected = role == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? const Color(0xFF1F2430) : const Color(0xFF8A909B),
            ),
          ),
        ),
      ),
    );
  }
}

/// 회색 채움 입력 필드(제목/내용/피드백 공용).
class _FilledInput extends StatelessWidget {
  const _FilledInput({
    required this.controller,
    required this.hint,
    this.validator,
    this.minLines = 1,
    this.maxLines = 1,
  });
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      minLines: minLines,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 15, color: Color(0xFF1F2430), height: 1.4),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _hint, fontSize: 15, height: 1.4),
        filled: true,
        fillColor: _fieldBg,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _border(),
        enabledBorder: _border(),
        focusedBorder: _border(focused: true),
        errorBorder: _border(error: true),
        focusedErrorBorder: _border(error: true),
      ),
    );
  }
}

/// 탭하면 피커가 뜨는 회색 채움 박스(날짜/시간).
class _TapBox extends StatelessWidget {
  const _TapBox({
    required this.icon,
    required this.text,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: _fieldBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: _icon),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1F2430),
                      fontWeight: FontWeight.w500)),
            ),
            if (trailing != null) Icon(trailing, size: 20, color: _icon),
          ],
        ),
      ),
    );
  }
}

OutlineInputBorder _border({bool focused = false, bool error = false}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: error
        ? const BorderSide(color: Color(0xFFE53E3E), width: 1.2)
        : focused
            ? const BorderSide(color: Color(0xFF102A6B), width: 1.4)
            : BorderSide.none,
  );
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
                color: _fieldBg,
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
