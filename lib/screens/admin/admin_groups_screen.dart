import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/repository.dart';
import '../../l10n/app_strings.dart';
import '../../models/group.dart';
import 'group_detail_screen.dart';

/// 관리자: 그룹(팀) 생성·목록·열람. 그룹을 열면 그 그룹의 보고서를 본다.
class AdminGroupsScreen extends StatefulWidget {
  const AdminGroupsScreen({super.key, this.showLogout = false, this.onLogout});
  final bool showLogout;
  final VoidCallback? onLogout;

  @override
  State<AdminGroupsScreen> createState() => _AdminGroupsScreenState();
}

class _AdminGroupsScreenState extends State<AdminGroupsScreen> {
  late Future<List<Group>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppRepository>().fetchGroups();
  }

  Future<void> _createGroup() async {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(context, 'create_group')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: tr(context, 'group_name')),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? tr(context, 'err_name')
                    : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: pinCtrl,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: tr(context, 'group_pin'),
                  helperText: tr(context, 'group_pin_hint'),
                ),
                validator: (v) => (v == null || v.trim().length != 4)
                    ? tr(context, 'err_pin4')
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'cancel'))),
          FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: Text(tr(context, 'create_group'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context
        .read<AppRepository>()
        .createGroup(nameCtrl.text, pinCtrl.text);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'group_created'))));
  }

  Future<void> _deleteGroup(Group g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(tr(context, 'delete_group')),
        content: Text('${g.name}\n${tr(context, 'delete_group_body')}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE53E3E)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'delete')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppRepository>().deleteGroup(g.id);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'group_deleted'))));
  }

  void _openGroup(Group g) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GroupDetailScreen(groupId: g.id, groupName: g.name),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(tr(context, 'groups_title'),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createGroup,
        backgroundColor: AppTheme.brand500,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.group_add),
        label: Text(tr(context, 'create_group')),
      ),
      body: FutureBuilder<List<Group>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final groups = snap.data ?? [];
          if (groups.isEmpty) {
            return Center(
              child: Text(tr(context, 'no_groups'),
                  style: TextStyle(color: Colors.grey.shade500)),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              itemCount: groups.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final g = groups[i];
                return Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    onTap: () => _openGroup(g),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(color: const Color(0x0F000000)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                                color: AppTheme.brandTonal,
                                shape: BoxShape.circle),
                            child: const Icon(Icons.groups,
                                color: AppTheme.brandOnTonal),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.pin, size: 14,
                                        color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text('PIN ${g.pin}',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.grey.shade600)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: Color(0xFFE53E3E)),
                            onPressed: () => _deleteGroup(g),
                          ),
                          const Icon(Icons.chevron_right,
                              color: Color(0xFFBDBDBD)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
