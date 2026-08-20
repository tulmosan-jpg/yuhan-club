import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/repository.dart';
import '../../l10n/app_strings.dart';
import '../../models/reward.dart';

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
    ]);
    final cfg = results[0] as RewardConfig;
    _codeCtrl.text = cfg.code;
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
    await context.read<AppRepository>().setRewardCode(code);
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr(context, 'code_saved'))));
  }

  Future<void> _editStock(Drink d, int current) async {
    final ctrl = TextEditingController(text: '$current');
    final v = await showDialog<int>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: Text('${d.name} ${tr(dctx, 'reward_stock')}',
            style: const TextStyle(
                fontFamily: 'Pretendard', fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(hintText: tr(dctx, 'stock_count')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx),
              child: Text(tr(dctx, 'cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _purple),
            onPressed: () =>
                Navigator.pop(dctx, int.tryParse(ctrl.text.trim()) ?? current),
            child: Text(tr(dctx, 'confirm')),
          ),
        ],
      ),
    );
    if (v == null || !mounted) return;
    await context.read<AppRepository>().setDrinkStock(d.id, v);
    if (!mounted) return;
    _reload();
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
