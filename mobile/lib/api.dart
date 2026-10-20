import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config.dart';
import 'models.dart';

class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);
  @override
  String toString() => message;
}

class Api {
  String? token;
  void Function()? onUnauthorized;

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, Uri.parse('$apiBase$path'))
      ..headers['Content-Type'] = 'application/json'
      ..headers.addAll({if (token != null) 'Authorization': 'Bearer $token'});
    if (body != null) req.body = jsonEncode(body);
    http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 30)));
    } catch (_) {
      throw ApiException(0, 'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ ($apiBase)');
    }
    final data = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode == 401 && token != null) onUnauthorized?.call();
    if (res.statusCode >= 400) {
      throw ApiException(res.statusCode, (data is Map ? data['error'] : null) ?? 'เกิดข้อผิดพลาด (${res.statusCode})');
    }
    return data;
  }

  // auth
  Future<(String, User)> login(String username, String password) async {
    final d = await _send('POST', '/auth/login', {'username': username, 'password': password});
    return (d['token'] as String, User.fromJson(d['user']));
  }

  Future<(String, User)> loginWithGoogle(String idToken) async {
    final d = await _send('POST', '/auth/google', {'id_token': idToken});
    return (d['token'] as String, User.fromJson(d['user']));
  }

  /// { google_client_id, allowed_domain } — client ID ตั้งไว้ที่ backend/.env ที่เดียว
  Future<Map<String, dynamic>> authConfig() async => Map<String, dynamic>.from(await _send('GET', '/auth/config'));

  Future<User> me() async => User.fromJson(await _send('GET', '/auth/me'));
  Future<Map<String, dynamic>> myStats() async => Map<String, dynamic>.from(await _send('GET', '/auth/me/stats'));

  // ร้าน
  Future<List<String>> categories() async => (await _send('GET', '/categories') as List).cast<String>();

  Future<List<Shop>> shops({String q = '', String category = ''}) async {
    final qs = Uri(queryParameters: {if (q.isNotEmpty) 'q': q, if (category.isNotEmpty) 'category': category}).query;
    return (await _send('GET', '/shops${qs.isEmpty ? '' : '?$qs'}') as List).map((e) => Shop.fromJson(e)).toList();
  }

  Future<Shop> shop(int id) async => Shop.fromJson(await _send('GET', '/shops/$id'));
  Future<List<String>> slots(int shopId) async => (await _send('GET', '/shops/$shopId/slots') as List).cast<String>();

  // เมนูโปรด
  Future<List<MenuItem>> favorites() async =>
      (await _send('GET', '/favorites') as List).map((e) => MenuItem.fromJson(e)).toList();
  Future<void> setFavorite(int menuItemId, bool fav) => _send(fav ? 'PUT' : 'DELETE', '/favorites/$menuItemId');

  // ออเดอร์
  Future<Order> createOrder({required int shopId, required Map<int, int> items, required String pickupTime, String note = ''}) async {
    final d = await _send('POST', '/orders', {
      'shop_id': shopId,
      'items': [for (final e in items.entries) {'menu_item_id': e.key, 'qty': e.value}],
      'pickup_time': pickupTime,
      'note': note,
    });
    return Order.fromJson(d);
  }

  Future<List<Order>> orders({bool history = false}) async =>
      (await _send('GET', '/orders?scope=${history ? 'history' : 'active'}') as List).map((e) => Order.fromJson(e)).toList();

  Future<Order> cancelOrder(int id) async => Order.fromJson(await _send('POST', '/orders/$id/cancel'));

  // ผู้ช่วยแนะนำเมนู — messages: [{'role': 'user'|'assistant', 'text': ...}]
  Future<AiReply> aiChat(List<Map<String, String>> messages) async =>
      AiReply.fromJson(await _send('POST', '/ai/chat', {'messages': messages}));
}
