import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/theme.dart';
import '../../data/auth_service.dart';
import '../../data/login_prefs.dart';
import '../../l10n/app_strings.dart';

/// 이메일/비밀번호 로그인 + 회원가입 (토글) 화면.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _isSignUp = false;
  bool _obscure = true;
  bool _busy = false;
  bool _rememberEmail = false;
  bool _autoLogin = false;
  bool _adminMode = false; // 관리자 로그인 탭 선택 여부

  @override
  void initState() {
    super.initState();
    LoginPrefs.load().then((prefs) {
      if (!mounted) return;
      setState(() {
        _rememberEmail = prefs.rememberEmail;
        _autoLogin = prefs.autoLogin;
        if (prefs.rememberEmail) _email.text = prefs.savedEmail;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthService>();
    try {
      if (_adminMode) {
        // 관리자 로그인: 인증 후 관리자 여부 검증. 아니면 로그아웃 + 에러.
        await auth.signIn(email: _email.text, password: _password.text);
        final isAdmin = await auth.checkIsAdmin();
        if (!isAdmin) {
          await auth.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr(context, 'not_admin'))));
            setState(() => _busy = false);
          }
          return;
        }
        auth.loggedInAsAdmin = true;
      } else if (_isSignUp) {
        await auth.signUp(
          email: _email.text,
          password: _password.text,
          name: _name.text,
        );
        auth.loggedInAsAdmin = false;
      } else {
        await auth.signIn(email: _email.text, password: _password.text);
        // 관리자 계정은 일반 로그인으로 들어올 수 없다(관리자 로그인 사용).
        if (await auth.checkIsAdmin()) {
          await auth.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(tr(context, 'use_admin_login'))));
            setState(() => _busy = false);
          }
          return;
        }
        auth.loggedInAsAdmin = false;
      }
      // 아이디 저장 / 자동 로그인 설정 저장.
      await LoginPrefs.save(
        rememberEmail: _rememberEmail,
        email: _email.text,
        autoLogin: _autoLogin,
      );
      // 성공 시 AuthGate가 자동으로 홈으로 전환.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, AuthService.errorKey(e)))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'enter_email_first'))),
      );
      return;
    }
    try {
      await context.read<AuthService>().sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, 'pw_reset_sent'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(context, AuthService.errorKey(e)))),
        );
      }
    }
  }

  void _setMode(bool signUp) {
    if (_isSignUp == signUp) return;
    setState(() => _isSignUp = signUp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── 엠블럼 ──
                    Center(
                      child: Container(
                        width: 110,
                        height: 110,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppTheme.brandTonal,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x1A114033),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/yuhan_emblem.png',
                            width: 88,
                            height: 88,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.eco,
                              size: 52,
                              color: AppTheme.brand500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      tr(context, 'app_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: AppTheme.brand900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _adminMode
                          ? tr(context, 'admin_login_subtitle')
                          : (_isSignUp
                              ? tr(context, 'signup_subtitle')
                              : tr(context, 'login_subtitle')),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF71717A),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── 로그인/회원가입 세그먼트 (일반 모드에서만) ──
                    if (!_adminMode) ...[
                      _SegmentToggle(
                        isSignUp: _isSignUp,
                        onChanged: _busy ? null : _setMode,
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── 이름 (일반 회원가입 시) ──
                    if (_isSignUp) ...[
                      _Field(
                        controller: _name,
                        hint: tr(context, 'name'),
                        icon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? tr(context, 'err_name')
                            : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── 이메일 ──
                    _Field(
                      controller: _email,
                      hint: tr(context, 'email'),
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
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
                    const SizedBox(height: 16),

                    // ── 비밀번호 ──
                    _Field(
                      controller: _password,
                      hint: tr(context, 'password'),
                      icon: Icons.lock_outline,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      suffix: IconButton(
                        splashRadius: 20,
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: const Color(0xFF9CA3AF),
                          size: 22,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? tr(context, 'err_pw_len')
                          : null,
                    ),

                    // ── 아이디 저장 / 자동 로그인 + 비밀번호 찾기 ──
                    if (!_isSignUp) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _CheckRow(
                            label: tr(context, 'remember_email'),
                            value: _rememberEmail,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _rememberEmail = v),
                          ),
                          const SizedBox(width: 14),
                          _CheckRow(
                            label: tr(context, 'auto_login'),
                            value: _autoLogin,
                            onChanged: _busy
                                ? null
                                : (v) => setState(() => _autoLogin = v),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: _busy ? null : _resetPassword,
                            behavior: HitTestBehavior.opaque,
                            child: Text(
                              tr(context, 'forgot_pw'),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.brand500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    SizedBox(height: _isSignUp ? 28 : 22),

                    // ── 그라디언트 로그인/회원가입 버튼 ──
                    _GradientButton(
                      label: _adminMode
                          ? tr(context, 'admin_login')
                          : (_isSignUp
                              ? tr(context, 'signup')
                              : tr(context, 'login')),
                      busy: _busy,
                      onPressed: _busy ? null : _submit,
                    ),
                    const SizedBox(height: 24),

                    // ── 하단 전환 링크 (일반 모드에서만) ──
                    if (!_adminMode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isSignUp
                              ? tr(context, 'have_account')
                              : tr(context, 'no_account'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF71717A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: _busy ? null : () => _setMode(!_isSignUp),
                          child: Text(
                            _isSignUp ? tr(context, 'login') : tr(context, 'signup'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.brand500,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── 하단: 관리자 로그인 / 일반 로그인 전환 (작게) ──
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _adminMode = !_adminMode;
                                  _isSignUp = false;
                                }),
                        icon: Icon(
                          _adminMode ? Icons.arrow_back : Icons.shield_outlined,
                          size: 15,
                          color: const Color(0xFF9CA3AF),
                        ),
                        label: Text(
                          _adminMode
                              ? tr(context, 'login_user')
                              : tr(context, 'admin_login'),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 작은 체크박스 + 라벨 (아이디 저장 / 자동 로그인).
class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
              value: value,
              onChanged:
                  onChanged == null ? null : (v) => onChanged!(v ?? false),
              activeColor: AppTheme.brand500,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF52525B),
            ),
          ),
        ],
      ),
    );
  }
}

/// 로그인 / 회원가입 세그먼트 토글 (pill).
class _SegmentToggle extends StatelessWidget {
  const _SegmentToggle({required this.isSignUp, required this.onChanged});
  final bool isSignUp;
  final void Function(bool signUp)? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: const Color(0x14000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          _seg(tr(context, 'login'),
              selected: !isSignUp, onTap: () => onChanged?.call(false)),
          _seg(tr(context, 'signup'),
              selected: isSignUp, onTap: () => onChanged?.call(true)),
        ],
      ),
    );
  }

  Widget _seg(String label,
      {required bool selected, required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.brand500 : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF71717A),
            ),
          ),
        ),
      ),
    );
  }
}

/// 시안 스타일 입력 필드 (56 높이, 녹색 아이콘/포커스, radius 14).
class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.hint,
    required this.icon,
    this.suffix,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final Widget? suffix;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppTheme.brand900,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontWeight: FontWeight.normal,
        ),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: AppTheme.brand600, size: 22),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusField),
          borderSide: const BorderSide(color: Color(0x14000000)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusField),
          borderSide: const BorderSide(color: Color(0x14000000)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusField),
          borderSide: const BorderSide(color: AppTheme.brand500, width: 1.6),
        ),
      ),
    );
  }
}

/// 녹색 그라디언트 + glow 그림자 주요 버튼.
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });
  final String label;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusField),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brand500, AppTheme.brand600],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brand500.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusField),
          onTap: onPressed,
          child: SizedBox(
            height: 56,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
