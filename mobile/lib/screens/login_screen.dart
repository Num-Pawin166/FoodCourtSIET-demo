import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../google_auth.dart';
import '../google_button_stub.dart' if (dart.library.js_interop) '../google_button_web.dart';
import '../theme.dart';
import '../widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  // Google
  String _domain = 'kmitl.ac.th';
  bool _googleReady = false;
  String? _googleNote;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleSub;

  @override
  void initState() {
    super.initState();
    _setupGoogle();
  }

  @override
  void dispose() {
    _googleSub?.cancel();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _setupGoogle() async {
    try {
      final cfg = await context.read<AppState>().api.authConfig();
      _domain = cfg['allowed_domain'] ?? _domain;
      final clientId = cfg['google_client_id'] as String?;
      if (clientId == null || clientId.isEmpty) {
        if (mounted) setState(() => _googleNote = 'ยังไม่ได้ตั้งค่า Google Sign-In ที่เซิร์ฟเวอร์');
        return;
      }
      await GoogleAuth.init(clientId: clientId, domain: _domain);
      _googleSub = GoogleAuth.events.listen(_onGoogleEvent, onError: _onGoogleError);
      if (mounted) setState(() => _googleReady = true);
    } catch (e) {
      if (mounted) setState(() => _googleNote = 'ใช้ Google Sign-In ไม่ได้: $e');
    }
  }

  Future<void> _onGoogleEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    final idToken = event.user.authentication.idToken;
    if (idToken == null) return _showError('ไม่ได้รับข้อมูลยืนยันตัวตนจาก Google');
    await _run(() => context.read<AppState>().loginWithGoogle(idToken), signOutOnError: true);
  }

  void _onGoogleError(Object e) {
    // ผู้ใช้ปิดหน้าต่างเลือกบัญชีเอง ไม่ต้องแจ้ง
    if (e is GoogleSignInException && e.code == GoogleSignInExceptionCode.canceled) return;
    _showError(e is GoogleSignInException ? (e.description ?? e.code.name) : e);
  }

  Future<void> _googleTap() async {
    try {
      await GoogleAuth.authenticate(); // ผลลัพธ์มาทาง _onGoogleEvent
    } catch (e) {
      _onGoogleError(e);
    }
  }

  Future<void> _passwordLogin() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) return _showError('กรุณากรอกข้อมูลให้ครบ');
    await _run(() => context.read<AppState>().login(_username.text, _password.text));
  }

  Future<void> _run(Future<void> Function() fn, {bool signOutOnError = false}) async {
    setState(() => _loading = true);
    try {
      await fn();
    } catch (e) {
      // เช่น อีเมลไม่ใช่ @kmitl.ac.th → ออกจาก Google ด้วย จะได้เลือกบัญชีใหม่ได้
      if (signOutOnError) await GoogleAuth.signOut().catchError((_) {});
      _showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(Object e) {
    if (mounted) showMsg(context, e, error: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(children: [
                const _Sparkles(child: FoodCourtLogo(size: 64)),
                const SizedBox(height: 40),
                _googleSection(),
                const SizedBox(height: 20),
                const Row(children: [
                  Expanded(child: Divider(color: AppColors.line)),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('หรือใช้รหัสผ่าน', style: TextStyle(fontSize: 12, color: AppColors.muted))),
                  Expanded(child: Divider(color: AppColors.line)),
                ]),
                const SizedBox(height: 16),
                TextField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Name', prefixIcon: Icon(Icons.person, color: AppColors.ink2)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  onSubmitted: (_) => _passwordLogin(),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock, color: AppColors.ink2),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: AppColors.muted),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                PinkButton(onPressed: _passwordLogin, loading: _loading, child: const Text('Login')),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _googleSection() {
    final Widget button;
    if (!_googleReady) {
      button = OutlinedButton.icon(
        onPressed: null,
        icon: const _GoogleG(),
        label: Text(_googleNote ?? 'กำลังโหลด...', style: const TextStyle(fontSize: 13)),
        style: _googleStyle,
      );
    } else if (GoogleAuth.canAuthenticate) {
      button = OutlinedButton.icon(
        onPressed: _loading ? null : _googleTap,
        icon: const _GoogleG(),
        label: const Text('เข้าสู่ระบบด้วย Google', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
        style: _googleStyle,
      );
    } else {
      button = SizedBox(height: 44, child: buildGoogleWebButton()); // เว็บ: ปุ่มของ Google
    }
    return Column(children: [
      SizedBox(width: double.infinity, child: Center(child: button)),
      const SizedBox(height: 8),
      Text('สำหรับนักศึกษาและบุคลากร ใช้อีเมล @$_domain เท่านั้น', style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
    ]);
  }

  static final _googleStyle = OutlinedButton.styleFrom(
    minimumSize: const Size(double.infinity, 52),
    backgroundColor: Colors.white,
    side: const BorderSide(color: Color(0xFFD9D9D9)),
    shape: const StadiumBorder(),
  );
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) => const Text('G',
      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4285F4)));
}

/// ดาวประดับรอบโลโก้แบบในดีไซน์
class _Sparkles extends StatelessWidget {
  final Widget child;
  const _Sparkles({required this.child});

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        child,
        const Positioned(left: -26, top: 30, child: Icon(Icons.auto_awesome, color: Color(0xFF8FA8E8), size: 30)),
        const Positioned(left: -6, top: 70, child: Icon(Icons.star_rounded, color: Color(0xFFB7C6F2), size: 16)),
        const Positioned(right: 30, top: -18, child: Icon(Icons.local_florist_outlined, color: AppColors.pink, size: 26)),
      ]);
}
