import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/attendance_logic.dart';
import '../../data/repository.dart';
import '../../l10n/app_strings.dart';
import '../../models/attendance.dart';
import '../../models/reward.dart';
import '../../widgets/app_dialog.dart';

const Color _purple = Color(kPaikNavyValue);

/// 출석 화면에 들어가는 빽다방 리워드 섹션.
/// 연속 출석 2회당 음료 쿠폰 1개. 매장(부천역곡역북부점) 직원 코드로 사용 처리.
class RewardSection extends StatefulWidget {
  const RewardSection({super.key, required this.summary});
  final AttendanceSummary summary;

  @override
  State<RewardSection> createState() => _RewardSectionState();
}

class _RewardSectionState extends State<RewardSection> {
  RewardConfig? _config;
  int _available = 0;
  List<Coupon> _coupons = [];
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RewardSection old) {
    super.didUpdateWidget(old);
    if (old.summary.currentStreak != widget.summary.currentStreak) _load();
  }

  Future<void> _load() async {
    final repo = context.read<AppRepository>();
    try {
      final results = await Future.wait([
        repo.fetchRewardConfig(),
        repo.fetchAvailableCoupons(widget.summary),
        repo.fetchMyCoupons(),
      ]);
      if (!mounted) return;
      setState(() {
        _config = results[0] as RewardConfig;
        _available = results[1] as int;
        _coupons = results[2] as List<Coupon>;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openClaimSheet() async {
    final cfg = _config;
    if (cfg == null) return;
    final drinkId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DrinkPicker(config: cfg),
    );
    if (drinkId == null || !mounted) return;
    await _claim(drinkId);
  }

  Future<void> _claim(String drinkId) async {
    setState(() => _busy = true);
    final repo = context.read<AppRepository>();
    try {
      await repo.claimCoupon(drinkId, widget.summary);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'coupon_issued'))));
      await _load();
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('resource-exhausted') ||
              e.toString().contains('sold_out')
          ? tr(context, 'coupon_sold_out')
          : e.toString().contains('failed-precondition') ||
                  e.toString().contains('not_eligible')
              ? tr(context, 'coupon_not_eligible')
              : tr(context, 'coupon_failed');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _redeem(Coupon c) async {
    final code = await showPinDialog(
      context: context,
      title: tr(context, 'redeem_title'),
      message: tr(context, 'redeem_desc'),
      confirmText: tr(context, 'redeem_confirm'),
      confirmColor: _purple,
    );
    if (code == null || !mounted) return;
    setState(() => _busy = true);
    final repo = context.read<AppRepository>();
    try {
      final success = await repo.redeemCoupon(c.id, code.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tr(
              context, success ? 'redeem_success' : 'redeem_bad_code'))));
      if (success) await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final cfg = _config;
    final active = _coupons.where((c) => !c.used).toList();
    final used = _coupons.where((c) => c.used).toList();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x0F000000)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(kPaikLogo, height: 16),
              const SizedBox(width: 6),
              Text(tr(context, 'reward_section_title'),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(tr(context, 'reward_section_sub'),
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
          const SizedBox(height: 14),

          // 발급 버튼(받을 수 있는 쿠폰이 있을 때).
          if (_available > 0)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _openClaimSheet,
                style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    minimumSize: const Size.fromHeight(48)),
                icon: const Icon(Icons.card_giftcard, size: 20),
                label: Text(
                    tr(context, 'reward_claim_n', {'n': '$_available'}),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F5FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tr(context, 'reward_none_yet',
                    {'n': '${AttendanceLogic.coffeeStreak}'}),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
            ),

          // 남은 수량.
          if (cfg != null) ...[
            const SizedBox(height: 14),
            Text(tr(context, 'reward_stock'),
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: kDrinks.map((d) {
                final n = cfg.remaining(d.id);
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F5FA),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Image.asset(d.image, height: 34),
                        const SizedBox(height: 4),
                        Text(_shortName(d.id),
                            style: const TextStyle(fontSize: 10.5),
                            textAlign: TextAlign.center),
                        Text('$n',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: n > 0 ? _purple : Colors.grey)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // 내 쿠폰.
          if (active.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(tr(context, 'my_coupons'),
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...active.map((c) => _CouponCard(
                  coupon: c,
                  onRedeem: _busy ? null : () => _redeem(c),
                )),
          ],
          if (used.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(tr(context, 'used_coupons'),
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade400)),
            const SizedBox(height: 6),
            ...used.map((c) => _CouponCard(coupon: c, onRedeem: null)),
          ],
        ],
      ),
    );
  }

  String _shortName(String id) => switch (id) {
        'peachtea' => '복숭아 아이스티',
        _ => '아메리카노',
      };
}

// ── 음료 선택 바텀시트 ──────────────────────────────────────────
class _DrinkPicker extends StatelessWidget {
  const _DrinkPicker({required this.config});
  final RewardConfig config;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: const Color(0xFFE4E4E7),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text(tr(context, 'choose_drink'),
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(tr(context, 'choose_drink_sub'),
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            ...kDrinks.map((d) {
              final n = config.remaining(d.id);
              final out = n <= 0;
              return Opacity(
                opacity: out ? 0.45 : 1,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x14000000)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: out ? null : () => Navigator.pop(context, d.id),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(d.image, height: 64),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(d.name,
                                          style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                    Text(
                                        out
                                            ? tr(context, 'sold_out')
                                            : tr(context, 'remaining_n',
                                                {'n': '$n'}),
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: out ? Colors.grey : _purple)),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(d.nutrition,
                                    style: TextStyle(
                                        fontSize: 11,
                                        height: 1.4,
                                        color: Colors.grey.shade600)),
                                if (d.caution != null) ...[
                                  const SizedBox(height: 3),
                                  Text(d.caution!,
                                      style: const TextStyle(
                                          fontSize: 10.5,
                                          height: 1.35,
                                          color: Color(0xFFB45309))),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── 쿠폰 카드 ───────────────────────────────────────────────────
class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon, this.onRedeem});
  final Coupon coupon;
  final VoidCallback? onRedeem;

  @override
  Widget build(BuildContext context) {
    final drink = drinkById(coupon.drinkId);
    final used = coupon.used;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: used ? const Color(0xFFFAFAFA) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: used ? const Color(0x11000000) : _purple.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          if (drink != null)
            Opacity(opacity: used ? 0.4 : 1, child: Image.asset(drink.image, height: 46)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(coupon.drinkName,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: used ? Colors.grey : Colors.black87)),
                const SizedBox(height: 2),
                Text(tr(context, 'reward_store'),
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                Text(
                    '${tr(context, 'issued_at')} ${DateFormat('M/d', 'ko').format(coupon.issuedAt)}'
                    '${used && coupon.usedAt != null ? ' · ${tr(context, 'used_at')} ${DateFormat('M/d', 'ko').format(coupon.usedAt!)}' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ),
          if (used)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEFEF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(tr(context, 'coupon_used_badge'),
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey)),
            )
          else
            FilledButton(
              onPressed: onRedeem,
              style: FilledButton.styleFrom(
                backgroundColor: _purple,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
              child: Text(tr(context, 'use_coupon'),
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
}
