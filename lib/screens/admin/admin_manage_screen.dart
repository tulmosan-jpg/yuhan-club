import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/auth_service.dart';
import '../../l10n/app_strings.dart';
import '../../widgets/app_dialog.dart';

/// 관리자 관리: 새 관리자 추가(Authentication 자동 등록) + 현재 관리자 목록/해제.
class AdminManageScreen extends StatefulWidget {
  const AdminManageScreen({super.key, this.showLogout = false, this.onLogout});
  final bool showLogout;
  final VoidCallback? onLogout;

  @override
  State<AdminManageScreen> createState() => _AdminManageScreenState();
}

class _AdminManageScreenState extends State<AdminManageScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  late Future<List<AdminInfo>> _admins;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _admins = context.read<AuthService>().listAdmins();
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _addAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthService>();
    try {
      await auth.createAdmin(
        email: _email.text,
        password: _password.text,
        name: _name.text,
      );
      if (!mounted) return;
      _email.clear();
      _password.clear();
      _name.clear();
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'admin_added'))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${tr(context, 'add_admin_failed')}: ${AuthService.errorKey(e) == 'auth_email_in_use' ? tr(context, 'auth_email_in_use') : e}')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removeAdmin(AdminInfo a) async {
    final ok = await showConfirmDialog(
      context: context,
      icon: Icons.shield_outlined,
      destructive: true,
      title: tr(context, 'remove_admin_title'),
      message: '${a.email}\n${tr(context, 'remove_admin_body')}',
      confirmText: tr(context, 'delete'),
    );
    if (!ok || !mounted) return;
    await context.read<AuthService>().removeAdmin(a.uid);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'admin_removed'))));
  }

  @override
  Widget build(BuildContext context) {
    final myUid = context.read<AuthService>().currentUser?.uid;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(tr(context, 'admin_manage_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (widget.showLogout)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: tr(context, 'logout'),
              onPressed: widget.onLogout,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── 새 관리자 추가 폼 ──
          Text(tr(context, 'add_admin_section'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(tr(context, 'add_admin_hint'),
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
          const SizedBox(height: 14),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: tr(context, 'name'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? tr(context, 'err_name')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: tr(context, 'email'),
                    prefixIcon: const Icon(Icons.mail_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return tr(context, 'err_email_empty');
                    }
                    if (!v.contains('@') || !v.contains('.')) {
                      return tr(context, 'err_email_invalid');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: tr(context, 'password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.length < 6)
                      ? tr(context, 'err_pw_len')
                      : null,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _busy ? null : _addAdmin,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.person_add_alt),
                    label: Text(tr(context, 'add_admin_button')),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 40),

          // ── 현재 관리자 목록 ──
          Text(tr(context, 'current_admins'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          FutureBuilder<List<AdminInfo>>(
            future: _admins,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final admins = snap.data ?? [];
              return Column(
                children: admins.map((a) {
                  final isMe = a.uid == myUid;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x0F000000)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined,
                            size: 20, color: AppTheme.brand600),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                        a.name.isEmpty ? a.email : a.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  if (isMe) ...[
                                    const SizedBox(width: 6),
                                    Text(tr(context, 'you_label'),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.brand600,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ],
                              ),
                              Text(a.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                        ),
                        // 본인은 해제 불가(권한 상실 방지).
                        if (!isMe)
                          IconButton(
                            icon: const Icon(Icons.person_remove_outlined,
                                size: 20, color: Color(0xFFE53E3E)),
                            tooltip: tr(context, 'remove_admin_title'),
                            onPressed: () => _removeAdmin(a),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
