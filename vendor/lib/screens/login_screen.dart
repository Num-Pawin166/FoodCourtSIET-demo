import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
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

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      return showMsg(context, 'กรุณากรอกข้อมูลให้ครบ', error: true);
    }
    setState(() => _loading = true);
    try {
      await context.read<AppState>().login(_username.text, _password.text);
    } catch (e) {
      if (mounted) showMsg(context, e, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
                const FoodCourtLogo(size: 60),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(99)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.storefront, color: AppColors.pink, size: 18),
                    SizedBox(width: 6),
                    Text('สำหรับร้านค้า', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'ชื่อผู้ใช้ร้าน', prefixIcon: Icon(Icons.store, color: AppColors.ink2)),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'รหัสผ่าน',
                    prefixIcon: const Icon(Icons.lock, color: AppColors.ink2),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20, color: AppColors.muted),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                PinkButton(onPressed: _submit, loading: _loading, child: const Text('เข้าสู่ระบบ')),
                const SizedBox(height: 16),
                const Text('ยังไม่มีบัญชี? ติดต่อผู้ดูแลศูนย์อาหาร', style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
