import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/repository.dart';
import '../../data/reward_excel.dart';
import '../../l10n/app_strings.dart';
import '../../models/reward.dart';
import '../../widgets/app_dialog.dart';

const Color _purple = Color(kPaikNavyValue);

/// 관리자: 리워드 코드·재고 설정 + 발급 쿠폰 현황.
class AdminRewardScreen extends StatefulWidget {
  const AdminRewardScreen({super.key, this.showLogout = false, this.onLogout});
  final bool showLogout;
  final VoidCallback? onLogout;

  @override
  State<AdminRewardScreen> createState() => _AdminRewardScreenState();
}

class _AdminRewardScreenState extends State<AdminRewardScreen> {
  late Future<_RewardAdminData> _future;
  final _codeCtrl = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<_RewardAdminData> _load() async {
    final repo = context.read<AppRepository>();
    final results = await Future.wait([
      repo.fetchRewardConfig(),
      repo.fetchAllCoupons(),
      repo.fetchRewardCode(), // 직원 코드는 secrets(관리자 전용)에서
    ]);
    final cfg = results[0] as RewardConfig;
    _codeCtrl.text = results[2] as String;
    return _RewardAdminData(cfg, results[1] as List<Coupon>);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _saveCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'code_must_be_4'))));
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AppRepository>().setRewardCode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr(context, 'code_saved'))));
    } catch (e) {
      // 실패를 삼키면 _busy 가 영구 true 로 남아 버튼이 잠긴다.
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${tr(context, 'stock_save_failed')}: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editStock(Drink d, int current) async {
    final s = await showInputDialog(
      context: context,
      title: '${d.name} ${tr(context, 'reward_stock')}',
      hint: tr(context, 'stock_count'),
      initialText: '$current',
      keyboardType: TextInputType.number,
      digitsOnly: true,
      confirmText: tr(context, 'confirm'),
      confirmColor: _purple,
    );
    if (s == null || !mounted) return;
    final v = int.tryParse(s.trim()) ?? current;
    setState(() => _busy = true);
    try {
      await context.read<AppRepository>().setDrinkStock(d.id, v);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'stock_saved'))));
    } catch (e) {
      // 예전에는 예외가 조용히 삼켜져 "변경이 안 된다"로만 보였다.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${tr(context, 'stock_save_failed')}: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 수령 완료 쿠폰(서명·영수증 포함)을 엑셀 명단으로 만들어 공유한다.
  Future<void> _exportRoster(List<Coupon> coupons) async {
    final used = coupons.where((c) => c.used).toList()
      ..sort((a, b) => (a.usedAt ?? a.issuedAt).compareTo(b.usedAt ?? b.issuedAt));
    if (used.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'roster_empty'))));
      return;
    }
    setState(() => _busy = true);
    try {
      final bytes = buildRewardRosterXlsx(used);
      final dir = await getTemporaryDirectory();
      final name =
          '리워드_수령자_명단_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [
          XFile(file.path,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        ],
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${tr(context, 'roster_export_failed')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(tr(context, 'reward_admin_title'),
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
      body: FutureBuilder<_RewardAdminData>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          final issued = d.coupons.length;
          final usedN = d.coupons.where((c) => c.used).length;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── 사용완료 코드 ──
                Text(tr(context, 'redeem_code_section'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(tr(context, 'redeem_code_hint'),
                    style:
                        TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
                const SizedBox(height: 10),
                TextField(
                  controller: _codeCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                      fontSize: 20,
                      letterSpacing: 6,
                      fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                      counterText: '', hintText: '0000'),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _saveCode,
                    style: FilledButton.styleFrom(
                        backgroundColor: _purple,
                        minimumSize: const Size.fromHeight(46)),
                    child: Text(tr(context, 'save')),
                  ),
                ),
                const Divider(height: 36),

                // ── 재고 ──
                Text(tr(context, 'reward_stock_section'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                ...kDrinks.map((drink) {
                  final n = d.config.remaining(drink.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x0F000000)),
                    ),
                    child: Row(
                      children: [
                        Image.asset(drink.image, height: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(drink.name,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                        Text('$n',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: n > 0 ? _purple : Colors.grey)),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          onPressed: () => _editStock(drink, n),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 36),

                // ── 발급 쿠폰 현황 ──
                Row(
                  children: [
                    Text(tr(context, 'issued_coupons'),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    Text(
                        tr(context, 'coupon_stats',
                            {'issued': '$issued', 'used': '$usedN'}),
                        style: TextStyle(
                            fontSize: 12.5, color: Colors.grey.shade600)),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.table_view_outlined, size: 20),
                      tooltip: tr(context, 'roster_export'),
                      color: _purple,
                      onPressed:
                          _busy ? null : () => _exportRoster(d.coupons),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (d.coupons.isEmpty)
                  Text(tr(context, 'no_coupons'),
                      style: TextStyle(color: Colors.grey.shade500))
                else
                  ...d.coupons.map((c) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0x0F000000)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${c.userName} · ${c.drinkName}',
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600)),
                                  Text(
                                      DateFormat('M/d HH:mm', 'ko')
                                          .format(c.issuedAt),
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.grey.shade500)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: c.used
                                    ? const Color(0xFFEFEFEF)
                                    : _purple.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                  tr(context,
                                      c.used ? 'coupon_used_badge' : 'coupon_active_badge'),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: c.used ? Colors.grey : _purple)),
                            ),
                          ],
                        ),
                      )),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RewardAdminData {
  final RewardConfig config;
  final List<Coupon> coupons;
  _RewardAdminData(this.config, this.coupons);
}
