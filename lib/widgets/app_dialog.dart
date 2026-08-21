import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../l10n/app_strings.dart';

// 앱 공용 다이얼로그 — 둥근 카드 + (선택)아이콘 배지 + 나란한 취소/액션 버튼.
// aidesigner ultradesign 시안 기반. AlertDialog의 어색한 버튼 배치를 대체.

const double _cardRadius = 24;
const double _btnRadius = 14;
const Color _title = Color(0xFF18181B);
const Color _muted = Color(0xFF6B7280);
const Color _danger = Color(0xFFE53E3E);
const Color _border = Color(0xFFE4E4E7);
const Color _cancelFg = Color(0xFF52525B);

Widget _iconBadge(IconData icon, Color color) => Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 28, color: color),
    );

Widget _cancelButton(BuildContext context, String label, VoidCallback onTap) =>
    Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: _border),
          foregroundColor: _cancelFg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(_btnRadius)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );

Widget _actionButton(String label, Color color, VoidCallback onTap) => Expanded(
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: color,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(_btnRadius)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );

Widget _shell({required Widget child}) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(_cardRadius)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: child,
      ),
    );

/// 확인 다이얼로그. 확인 시 true. [destructive]면 액션 버튼이 빨강.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
  String? cancelText,
  IconData? icon,
  bool destructive = false,
}) async {
  final color = destructive ? _danger : AppTheme.brand500;
  final result = await showDialog<bool>(
    context: context,
    builder: (dctx) => _shell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            _iconBadge(icon, color),
            const SizedBox(height: 18),
          ],
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: _title)),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5, color: _muted)),
          const SizedBox(height: 26),
          Row(
            children: [
              _cancelButton(dctx, cancelText ?? tr(dctx, 'cancel'),
                  () => Navigator.pop(dctx, false)),
              const SizedBox(width: 12),
              _actionButton(
                  confirmText, color, () => Navigator.pop(dctx, true)),
            ],
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}

/// 회색 채움 입력 필드 데코레이션(공용).
InputDecoration _filledInput(String? hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: const Color(0xFFF1F2F4),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_btnRadius),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_btnRadius),
          borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_btnRadius),
          borderSide: const BorderSide(color: AppTheme.brand500, width: 1.6)),
    );

/// 단일 입력 다이얼로그(텍스트/숫자). 확인 시 입력값, 취소 null.
Future<String?> showInputDialog({
  required BuildContext context,
  required String title,
  String? message,
  String? hint,
  String? initialText,
  required String confirmText,
  TextInputType? keyboardType,
  int? maxLength,
  bool digitsOnly = false,
  Color? confirmColor,
}) {
  final ctrl = TextEditingController(text: initialText ?? '');
  ctrl.selection = TextSelection.collapsed(offset: ctrl.text.length);
  return showDialog<String>(
    context: context,
    builder: (dctx) => _shell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.bold, color: _title)),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message,
                style: const TextStyle(fontSize: 14, height: 1.5, color: _muted)),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters:
                digitsOnly ? [FilteringTextInputFormatter.digitsOnly] : null,
            style: const TextStyle(fontSize: 16, color: _title),
            onSubmitted: (v) => Navigator.pop(dctx, v.trim()),
            decoration: _filledInput(hint),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _cancelButton(
                  dctx, tr(dctx, 'cancel'), () => Navigator.pop(dctx, null)),
              const SizedBox(width: 12),
              _actionButton(confirmText, confirmColor ?? AppTheme.brand500,
                  () => Navigator.pop(dctx, ctrl.text.trim())),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 그룹 만들기: 이름 + 4자리 PIN. 확인 시 (name, pin), 취소 null.
Future<({String name, String pin})?> showCreateGroupDialog({
  required BuildContext context,
  required String title,
  required String nameHint,
  required String pinHint,
  String? helper,
  required String confirmText,
}) {
  final nameCtrl = TextEditingController();
  final pinCtrl = TextEditingController();
  return showDialog<({String name, String pin})>(
    context: context,
    builder: (dctx) => _shell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.bold, color: _title)),
          const SizedBox(height: 16),
          TextField(
            controller: nameCtrl,
            autofocus: true,
            style: const TextStyle(fontSize: 16, color: _title),
            decoration: _filledInput(nameHint),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pinCtrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 16, color: _title),
            decoration: _filledInput(pinHint),
          ),
          if (helper != null) ...[
            const SizedBox(height: 4),
            Text(helper,
                style: const TextStyle(fontSize: 12, color: _muted)),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              _cancelButton(
                  dctx, tr(dctx, 'cancel'), () => Navigator.pop(dctx, null)),
              const SizedBox(width: 12),
              _actionButton(confirmText, AppTheme.brand500, () {
                Navigator.pop(dctx,
                    (name: nameCtrl.text.trim(), pin: pinCtrl.text.trim()));
              }),
            ],
          ),
        ],
      ),
    ),
  );
}

/// 4자리 PIN 입력 다이얼로그. 확인 시 입력값 문자열, 취소면 null.
Future<String?> showPinDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmText,
}) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dctx) => _shell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 19, fontWeight: FontWeight.bold, color: _title)),
          const SizedBox(height: 8),
          Text(message,
              style: const TextStyle(fontSize: 14, height: 1.5, color: _muted)),
          const SizedBox(height: 18),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
            onSubmitted: (v) => Navigator.pop(dctx, v.trim()),
            decoration: InputDecoration(
              counterText: '',
              hintText: '••••',
              hintStyle: const TextStyle(
                  color: Color(0xFFC4C7CC), letterSpacing: 12, fontSize: 22),
              filled: true,
              fillColor: const Color(0xFFF1F2F4),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_btnRadius),
                  borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_btnRadius),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_btnRadius),
                  borderSide:
                      const BorderSide(color: AppTheme.brand500, width: 1.6)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _cancelButton(dctx, tr(dctx, 'cancel'),
                  () => Navigator.pop(dctx, null)),
              const SizedBox(width: 12),
              _actionButton(confirmText, AppTheme.brand500,
                  () => Navigator.pop(dctx, ctrl.text.trim())),
            ],
          ),
        ],
      ),
    ),
  );
}
