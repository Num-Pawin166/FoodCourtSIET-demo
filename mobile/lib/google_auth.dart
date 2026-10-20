import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// ห่อ google_sign_in v7: ใช้ Web client ID ตัวเดียวกับ backend
/// - เว็บ: ส่งเป็น clientId (ปุ่มเป็นของ Google เอง ดู google_button_web.dart)
/// - Android: ส่งเป็น serverClientId เพื่อให้ได้ idToken ที่ backend ตรวจได้
class GoogleAuth {
  static bool _initialized = false;

  static Future<void> init({required String clientId, required String domain}) async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? clientId : null,
      serverClientId: kIsWeb ? null : clientId,
      hostedDomain: domain, // ให้หน้าเลือกบัญชีแสดงเฉพาะบัญชีโดเมนนี้ (backend ตรวจซ้ำอีกชั้น)
    );
    _initialized = true;
  }

  static bool get initialized => _initialized;

  /// Android/iOS กดปุ่มของเราเองได้ ส่วนเว็บต้องใช้ปุ่มที่ Google วาดให้
  static bool get canAuthenticate => GoogleSignIn.instance.supportsAuthenticate();

  static Stream<GoogleSignInAuthenticationEvent> get events => GoogleSignIn.instance.authenticationEvents;

  static Future<void> authenticate() => GoogleSignIn.instance.authenticate();

  static Future<void> signOut() async {
    if (_initialized) await GoogleSignIn.instance.signOut();
  }
}
