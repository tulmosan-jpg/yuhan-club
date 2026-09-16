import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme.dart';
import '../../data/image_util.dart';
import '../../l10n/app_strings.dart';
import '../../models/reward.dart';
import '../../widgets/signature_pad.dart';

/// 수령 확인 결과: 서명 PNG + 주문서/영수증 JPEG (둘 다 base64).
typedef RedeemProof = ({String signatureB64, String receiptB64});

/// 리워드 수령 확인 화면.
///
/// 직원 비밀번호 확인 후 진입한다. 수령자 전자서명과 주문서/영수증 사진을
/// **둘 다** 받아야 수령 완료 버튼이 눌린다.
class RedeemConfirmScreen extends StatefulWidget {
  const RedeemConfirmScreen({super.key, required this.coupon});

  final Coupon coupon;

  @override
  State<RedeemConfirmScreen> createState() => _RedeemConfirmScreenState();
}

class _RedeemConfirmScreenState extends State<RedeemConfirmScreen> {
  final _signature = SignaturePadController();
  String? _receiptB64;
  bool _pickingReceipt = false;
  bool _submitting = false;

  @override
  void dispose() {
    _signature.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    if (_pickingReceipt) return;
    setState(() => _pickingReceipt = true);
    try {
      final b64 = await pickResizedPhotoBase64(source: source);
      if (b64 != null && mounted) setState(() => _receiptB64 = b64);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr(context, 'photo_pick_failed'))));
      }
    } finally {
      if (mounted) setState(() => _pickingReceipt = false);
    }
  }

  Future<void> _submit() async {
    if (_signature.isEmpty || _receiptB64 == null || _submitting) return;
    setState(() => _submitting = true);
    final png = await _signature.toPngBytes();
    if (!mounted) return;
    if (png == null) {
      setState(() => _submitting = false);
      return;
    }
    Navigator.of(context).pop<RedeemProof>(
        (signatureB64: base64Encode(png), receiptB64: _receiptB64!));
  }

  @override
  Widget build(BuildContext context) {
    final ready = _receiptB64 != null;
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(tr(context, 'redeem_confirm_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            // 수령 대상 안내
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.brandTonal,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_cafe_outlined,
                      size: 20, color: AppTheme.brandOnTonal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.coupon.userName} · ${widget.coupon.drinkName}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.brandOnTonal),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── 1. 수령자 서명 ──
            _sectionLabel(context, '1. ${tr(context, 'redeem_sign_section')}'),
            const SizedBox(height: 8),
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4E4E7)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  Positioned.fill(child: SignaturePad(controller: _signature)),
                  // 비어 있을 때만 안내 문구. IgnorePointer 가 없으면 힌트
                  // 글자가 터치를 가로채 그 위에서 시작한 첫 획이 먹힌다.
                  IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _signature,
                      builder: (context, _) => _signature.isEmpty
                          ? Center(
                              child: Text(
                                tr(context, 'redeem_sign_hint'),
                                style: const TextStyle(
                                    fontSize: 15, color: Color(0xFF9CA3AF)),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _signature.clear(),
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(tr(context, 'redeem_sign_clear')),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B7280),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── 2. 주문서/영수증 사진 ──
            _sectionLabel(
                context, '2. ${tr(context, 'redeem_receipt_section')}'),
            const SizedBox(height: 8),
            if (_receiptB64 == null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickingReceipt
                          ? null
                          : () => _pickReceipt(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: Text(tr(context, 'redeem_receipt_camera')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: Color(0xFFE4E4E7)),
                        foregroundColor: const Color(0xFF52525B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickingReceipt
                          ? null
                          : () => _pickReceipt(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(tr(context, 'redeem_receipt_gallery')),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        side: const BorderSide(color: Color(0xFFE4E4E7)),
                        foregroundColor: const Color(0xFF52525B),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              )
            else
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      base64Decode(_receiptB64!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black54,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _receiptB64 = null),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child:
                              Icon(Icons.close, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 32),

            // ── 수령 완료 (주 버튼) ──
            AnimatedBuilder(
              animation: _signature,
              builder: (context, _) {
                final enabled = !_signature.isEmpty && ready && !_submitting;
                return FilledButton(
                  onPressed: enabled ? _submit : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppTheme.brand500,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(tr(context, 'redeem_complete_button'),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              tr(context, 'redeem_proof_required'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF18181B)),
      );
}
