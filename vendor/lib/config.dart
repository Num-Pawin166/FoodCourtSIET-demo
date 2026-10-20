import 'package:flutter/foundation.dart';

/// URL ของ backend
/// - ส่งค่าเองได้: flutter run --dart-define=API_URL=http://192.168.1.10:3000/api
/// - Android emulator เข้าถึงเครื่อง host ผ่าน 10.0.2.2
const _override = String.fromEnvironment('API_URL');

String get apiBase {
  if (_override.isNotEmpty) return _override;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:3000/api';
  }
  return 'http://localhost:3000/api';
}
