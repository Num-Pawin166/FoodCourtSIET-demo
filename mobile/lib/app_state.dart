import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'google_auth.dart';
import 'models.dart';

/// สถานะกลางของแอป: บัญชีผู้ใช้, แท็บปัจจุบัน, ร้านที่เลือก, ตะกร้า, เมนูโปรด
class AppState extends ChangeNotifier {
  final api = Api();

  User? user;
  bool restoring = true;

  AppState() {
    api.onUnauthorized = logout;
  }

  // ---------- auth ----------
  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      api.token = token;
      try {
        user = await api.me();
        await loadFavorites();
      } catch (_) {
        api.token = null;
      }
    }
    restoring = false;
    notifyListeners();
  }

  Future<void> _signedIn(String token, User u) async {
    if (u.role != 'student') {
      throw ApiException(403, 'บัญชีร้านค้า/ผู้ดูแล กรุณาใช้งานผ่านเว็บหลังบ้าน');
    }
    api.token = token;
    user = u;
    (await SharedPreferences.getInstance()).setString('token', token);
    await loadFavorites();
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
    final (token, u) = await api.login(username.trim(), password);
    await _signedIn(token, u);
  }

  Future<void> loginWithGoogle(String idToken) async {
    final (token, u) = await api.loginWithGoogle(idToken);
    await _signedIn(token, u);
  }

  Future<void> logout() async {
    try {
      await GoogleAuth.signOut(); // กันไม่ให้ Google ล็อกอินบัญชีเดิมให้อัตโนมัติ
    } catch (_) {}
    api.token = null;
    user = null;
    tab = 0;
    selectedShopId = null;
    clearCart();
    favoriteIds.clear();
    (await SharedPreferences.getInstance()).remove('token');
    notifyListeners();
  }

  // ---------- navigation ----------
  int tab = 0;
  int? selectedShopId;

  void goTab(int i) {
    tab = i;
    notifyListeners();
  }

  void openShop(int shopId) {
    selectedShopId = shopId;
    tab = 1;
    notifyListeners();
  }

  // ---------- ตะกร้า (สั่งได้ทีละร้าน) ----------
  Shop? cartShop;
  final Map<int, MenuItem> _cartItems = {};
  final Map<int, int> cartQty = {};
  String cartNote = '';

  int qtyOf(int menuItemId) => cartQty[menuItemId] ?? 0;
  int get cartCount => cartQty.values.fold(0, (a, b) => a + b);
  int get cartTotal => cartQty.entries.fold(0, (sum, e) => sum + _cartItems[e.key]!.price * e.value);
  List<(MenuItem, int)> get cartLines => [for (final e in cartQty.entries) (_cartItems[e.key]!, e.value)];
  bool isOtherShop(Shop shop) => cartShop != null && cartShop!.id != shop.id && cartQty.isNotEmpty;

  void setQty(Shop shop, MenuItem item, int qty) {
    if (isOtherShop(shop)) clearCart(notify: false);
    cartShop = shop;
    if (qty <= 0) {
      cartQty.remove(item.id);
      _cartItems.remove(item.id);
    } else {
      cartQty[item.id] = qty.clamp(1, 20);
      _cartItems[item.id] = item;
    }
    if (cartQty.isEmpty) cartShop = null;
    notifyListeners();
  }

  void clearCart({bool notify = true}) {
    cartShop = null;
    cartQty.clear();
    _cartItems.clear();
    cartNote = '';
    if (notify) notifyListeners();
  }

  /// "สั่งอีกครั้ง" จากประวัติ: ใส่เมนูที่ยังมีขายลงตะกร้า คืนจำนวนเมนูที่หมดแล้ว
  Future<int> reorder(Order order) async {
    final shop = await api.shop(order.shopId);
    clearCart(notify: false);
    var missing = 0;
    for (final line in order.items) {
      final item = shop.menu.where((m) => m.id == line.menuItemId && m.isAvailable).firstOrNull;
      if (item == null) {
        missing++;
      } else {
        cartShop = shop;
        cartQty[item.id] = line.qty;
        _cartItems[item.id] = item;
      }
    }
    cartNote = order.note;
    selectedShopId = shop.id;
    notifyListeners();
    return missing;
  }

  // ---------- เมนูโปรด ----------
  final Set<int> favoriteIds = {};

  Future<void> loadFavorites() async {
    final favs = await api.favorites();
    favoriteIds
      ..clear()
      ..addAll(favs.map((f) => f.id));
  }

  Future<void> toggleFavorite(int menuItemId) async {
    final fav = !favoriteIds.contains(menuItemId);
    fav ? favoriteIds.add(menuItemId) : favoriteIds.remove(menuItemId);
    notifyListeners();
    try {
      await api.setFavorite(menuItemId, fav);
    } catch (_) {
      fav ? favoriteIds.remove(menuItemId) : favoriteIds.add(menuItemId);
      notifyListeners();
      rethrow;
    }
  }
}
