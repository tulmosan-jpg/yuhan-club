import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/app_config.dart';
import '../../app/theme.dart';
import '../../data/messaging_service.dart';
import '../../data/notification_service.dart';
import '../../l10n/app_strings.dart';

/// 알림 설정(로컬 저장). 멘티/멘토 알림을 분리해 켜고 끈다.
/// 실제 푸시 발송은 아직 미연동 — 설정만 보관한다.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // key → 기본값
  static const _defaults = <String, bool>{
    'notif_enabled': true,
    'n_attend_reminder': true,
    'n_rsvp_reminder': true,
    'n_schedule_added': true,
    'n_new_notice': true,
    'n_new_report': true,
    'n_rsvp_declined': true,
  };

  final Map<String, bool> _v = {..._defaults};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    for (final k in _defaults.keys) {
      _v[k] = p.getBool(k) ?? _defaults[k]!;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _set(String key, bool value) async {
    setState(() => _v[key] = value);
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
    // 마스터 알림을 켜면 OS 권한 요청("허용하시겠습니까" 창).
    if (key == 'notif_enabled' && value) {
      await NotificationService.instance.requestPermission();
    }
    // 서버 알림 필터용으로 설정을 Firestore 에 동기화.
    if (!AppConfig.useMock) {
      await MessagingService.instance.syncPrefs();
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content: Text(tr(context, 'notif_saved')),
            duration: const Duration(milliseconds: 700)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final on = _v['notif_enabled'] ?? true;
    return Scaffold(
      appBar: AppBar(
          title: Text(tr(context, 'notif_settings'),
              style: const TextStyle(fontWeight: FontWeight.bold))),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 마스터 스위치
                Card(
                  child: SwitchListTile(
                    value: on,
                    onChanged: (v) => _set('notif_enabled', v),
                    title: Text(tr(context, 'notif_master'),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(tr(context, 'notif_master_sub')),
                    activeThumbColor: AppTheme.brand500,
                  ),
                ),
                const SizedBox(height: 16),
                _section(context, tr(context, 'notif_mentee_section'), [
                  _switch('n_attend_reminder', 'notif_attend_reminder',
                      'notif_attend_reminder_sub', on),
                  _switch('n_rsvp_reminder', 'notif_rsvp_reminder',
                      'notif_rsvp_reminder_sub', on),
                  _switch('n_schedule_added', 'notif_schedule_added',
                      'notif_schedule_added_sub', on),
                  _switch('n_new_notice', 'notif_new_notice', null, on),
                ]),
                const SizedBox(height: 16),
                _section(context, tr(context, 'notif_mentor_section'), [
                  _switch('n_new_report', 'notif_new_report',
                      'notif_new_report_sub', on),
                  _switch('n_rsvp_declined', 'notif_rsvp_declined',
                      'notif_rsvp_declined_sub', on),
                ]),
                const SizedBox(height: 20),
                Text(tr(context, 'notif_not_wired_note'),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600)),
        ),
        Card(child: Column(children: tiles)),
      ],
    );
  }

  Widget _switch(String key, String titleKey, String? subKey, bool masterOn) {
    return SwitchListTile(
      value: masterOn && (_v[key] ?? true),
      onChanged: masterOn ? (v) => _set(key, v) : null,
      title: Text(tr(context, titleKey)),
      subtitle: subKey == null ? null : Text(tr(context, subKey)),
      activeThumbColor: AppTheme.brand500,
    );
  }
}
