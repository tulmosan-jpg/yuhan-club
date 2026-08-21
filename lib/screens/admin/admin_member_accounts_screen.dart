import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/repository.dart';
import '../../l10n/app_strings.dart';
import '../../models/group.dart';
import '../../widgets/app_dialog.dart';

/// 관리자: 그룹 멤버의 로그인 아이디(이메일) 확인 + 임시 비밀번호 발급.
/// 멘티가 아이디/비밀번호를 잊었을 때 멘토(관리자)가 찾아준다.
class AdminMemberAccountsScreen extends StatefulWidget {
  const AdminMemberAccountsScreen(
      {super.key, required this.groupId, required this.groupName});
  final String groupId;
  final String groupName;

  @override
  State<AdminMemberAccountsScreen> createState() =>
      _AdminMemberAccountsScreenState();
}

class _AdminMemberAccountsScreenState extends State<AdminMemberAccountsScreen> {
  late Future<List<MemberAccount>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppRepository>().fetchGroupMemberAccounts(widget.groupId);
  }

  void _reload() => setState(() {
        _future =
            context.read<AppRepository>().fetchGroupMemberAccounts(widget.groupId);
      });

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'copied'))));
    }
  }

  Future<void> _resetPassword(MemberAccount m) async {
    final ok = await showConfirmDialog(
      context: context,
      icon: Icons.lock_reset,
      title: tr(context, 'reset_pw_title'),
      message: tr(context, 'reset_pw_body', {'name': m.name}),
      confirmText: tr(context, 'reset_pw_confirm'),
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      final res =
          await context.read<AppRepository>().resetMemberPassword(m.uid);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dctx) => AlertDialog(
          icon: const Icon(Icons.vpn_key, color: AppTheme.brand600, size: 32),
          title: Text(tr(dctx, 'temp_pw_title'),
              style: const TextStyle(
                  fontFamily: 'Pretendard', fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr(dctx, 'temp_pw_desc'),
                  style: const TextStyle(fontFamily: 'Pretendard', fontSize: 13)),
              const SizedBox(height: 12),
              _copyRow(dctx, tr(dctx, 'login_id'),
                  res.email.isEmpty ? m.email : res.email),
              const SizedBox(height: 8),
              _copyRow(dctx, tr(dctx, 'temp_pw'), res.password),
            ],
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(dctx),
                child: Text(tr(dctx, 'ok_great'))),
          ],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(context, 'reset_pw_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _copyRow(BuildContext ctx, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text('$label  ',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
          ),
          InkWell(
            onTap: () => _copy(value),
            child: const Icon(Icons.copy, size: 16, color: AppTheme.brand600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(context, 'member_accounts'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<MemberAccount>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final members = snap.data!;
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(tr(context, 'member_accounts_hint'),
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade500)),
                    const SizedBox(height: 12),
                    if (members.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(tr(context, 'attendance_none'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500)),
                      )
                    else
                      ...members.map((m) => Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0x0F000000)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: AppTheme.brandTonal,
                                      child: Text(
                                          m.name.isNotEmpty
                                              ? m.name.characters.first
                                              : '?',
                                          style: const TextStyle(
                                              color: AppTheme.brandOnTonal,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(m.name,
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                _copyRow(context, tr(context, 'login_id'),
                                    m.email.isEmpty ? '-' : m.email),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        _busy ? null : () => _resetPassword(m),
                                    icon: const Icon(Icons.lock_reset, size: 18),
                                    label:
                                        Text(tr(context, 'issue_temp_pw')),
                                  ),
                                ),
                              ],
                            ),
                          )),
                  ],
                ),
              ),
              if (_busy)
                Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
      ),
    );
  }
}
