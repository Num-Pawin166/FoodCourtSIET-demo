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

/// เรียก API ฝั่งร้านค้า (/api/vendor/*) — ผูกกับร้านของบัญชีที่ล็อกอินเสมอ
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
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 10)));
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

  Future<(String, Vendor)> login(String username, String password) async {
    final d = await _send('POST', '/auth/login', {'username': username, 'password': password});
    return (d['token'] as String, Vendor.fromJson(d['user']));
  }

  Future<Vendor> me() async => Vendor.fromJson(await _send('GET', '/auth/me'));

  // ร้าน
  Future<Shop> shop() async => Shop.fromJson(await _send('GET', '/vendor/shop'));
  Future<Shop> updateShop(Map<String, dynamic> body) async => Shop.fromJson(await _send('PATCH', '/vendor/shop', body));
  Future<Summary> summary() async => Summary.fromJson(await _send('GET', '/vendor/summary'));

  // ออเดอร์: scope = active (ยังไม่จบ) | today (ทั้งหมดของวันนี้)
  Future<List<Order>> orders({bool today = false}) async =>
      (await _send('GET', '/vendor/orders?scope=${today ? 'today' : 'active'}') as List).map((e) => Order.fromJson(e)).toList();

  Future<Order> setStatus(int orderId, String status, {String? reason}) async =>
      Order.fromJson(await _send('PATCH', '/vendor/orders/$orderId/status', {'status': status, 'reason': ?reason}));

  // เมนู
  Future<List<MenuItem>> menu() async => (await _send('GET', '/vendor/menu') as List).map((e) => MenuItem.fromJson(e)).toList();
  Future<void> createMenu(Map<String, dynamic> body) => _send('POST', '/vendor/menu', body);
  Future<void> updateMenu(int id, Map<String, dynamic> body) => _send('PATCH', '/vendor/menu/$id', body);
  Future<void> deleteMenu(int id) => _send('DELETE', '/vendor/menu/$id');
}
