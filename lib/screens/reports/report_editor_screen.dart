import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../data/repository.dart';
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
  late ReportRole _role;
  late TextEditingController _partner;
  late TextEditingController _title;
  late TextEditingController _content;
  late TextEditingController _feedback;
  late TextEditingController _hours;
  late DateTime _date;
  late TimeOfDay _time;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _role = e?.role ?? ReportRole.mentor;
    _partner = TextEditingController(text: e?.partnerName ?? '');
    _title = TextEditingController(text: e?.title ?? '');
    _content = TextEditingController(text: e?.content ?? '');
    _feedback = TextEditingController(text: e?.feedback ?? '');
    _hours =
        TextEditingController(text: e == null ? '' : '${e.activityHours}');
    _date = e?.activityDate ?? DateTime.now();
    _time = TimeOfDay.fromDateTime(e?.activityDate ?? DateTime.now());
  }

  @override
  void dispose() {
    _partner.dispose();
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
    setState(() => _saving = true);
    final repo = context.read<AppRepository>();
    final report = MentoringReport(
      id: widget.existing?.id ?? '',
      role: _role,
      authorName: repo.currentUserName,
      partnerName: _partner.text.trim(),
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
      status: status,
      updatedAt: DateTime.now(),
    );
    try {
      await repo.saveReport(report);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(status == ReportStatus.submitted
              ? '보고서를 제출했습니다.'
              : '임시저장했습니다.'),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? '보고서 수정' : '보고서 작성')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('작성자 역할',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<ReportRole>(
              segments: const [
                ButtonSegment(
                    value: ReportRole.mentor, label: Text('멘토')),
                ButtonSegment(
                    value: ReportRole.mentee, label: Text('멘티')),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 16),
            _field(
              _partner,
              _role == ReportRole.mentor ? '멘티 이름' : '멘토 이름',
              required: true,
            ),
            _field(_title, '제목', required: true),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '활동 일자',
                        isDense: true,
                        suffixIcon:
                            Icon(Icons.calendar_today_outlined, size: 18),
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
                      decoration: const InputDecoration(
                        labelText: '활동 시각',
                        isDense: true,
                        suffixIcon: Icon(Icons.access_time, size: 18),
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
            _field(_hours, '활동 소요시간 (시간)',
                keyboard: TextInputType.number, required: true),
            _field(_content, '활동 내용', required: true, maxLines: 6),
            _field(_feedback, '소감/피드백', required: true, maxLines: 4),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => _save(ReportStatus.draft),
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52)),
                    child: const Text('임시저장'),
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
                        : const Text('제출'),
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
                ? '$label을(를) 입력하세요'
                : null
            : null,
      ),
    );
  }
}
