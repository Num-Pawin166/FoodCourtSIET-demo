import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  final api = Api();
  Vendor? user;
  bool restoring = true;
  int tab = 0;

  AppState() {
    api.onUnauthorized = logout;
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('vendor_token');
    if (token != null) {
      api.token = token;
      try {
        user = await api.me();
        if (user!.role != 'vendor') user = null;
      } catch (_) {
        api.token = null;
      }
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final (token, u) = await api.login(username.trim(), password);
    if (u.role != 'vendor') throw ApiException(403, 'แอปนี้สำหรับบัญชีร้านค้าเท่านั้น');
    api.token = token;
    user = u;
    (await SharedPreferences.getInstance()).setString('vendor_token', token);
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    user = null;
    tab = 0;
    (await SharedPreferences.getInstance()).remove('vendor_token');
    notifyListeners();
  }

  void goTab(int i) {
    tab = i;
    notifyListeners();
  }
}
