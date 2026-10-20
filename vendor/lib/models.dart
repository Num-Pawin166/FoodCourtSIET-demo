class Vendor {
  final int id;
  final String username;
  final String name;
  final String role;

  Vendor({required this.id, required this.username, required this.name, required this.role});

  factory Vendor.fromJson(Map<String, dynamic> j) => Vendor(id: j['id'], username: j['username'], name: j['name'], role: j['role']);
}

class Shop {
  final int id;
  final String code;
  final String name;
  final String description;
  final String category;
  final String openTime;
  final String closeTime;
  final int prepMin;
  final int prepMax;
  final bool isOpen;
  final bool openNow;
  final int queueCount;

  Shop({
    required this.id, required this.code, required this.name, required this.description, required this.category,
    required this.openTime, required this.closeTime, required this.prepMin, required this.prepMax,
    required this.isOpen, required this.openNow, required this.queueCount,
  });

  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
        id: j['id'], code: j['code'], name: j['name'], description: j['description'] ?? '', category: j['category'],
        openTime: j['open_time'], closeTime: j['close_time'], prepMin: j['prep_min'], prepMax: j['prep_max'],
        isOpen: j['is_open'] == true, openNow: j['open_now'] == true, queueCount: j['queue_count'] ?? 0,
      );
}

class MenuItem {
  final int id;
  final String name;
  final String description;
  final int price;
  final bool isAvailable;
  final int sortOrder;

  MenuItem({required this.id, required this.name, required this.description, required this.price, required this.isAvailable, required this.sortOrder});

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j['id'], name: j['name'], description: j['description'] ?? '', price: j['price'],
        isAvailable: j['is_available'] == true, sortOrder: j['sort_order'] ?? 0,
      );
}

class OrderLine {
  final String name;
  final int qty;
  final int price;
  OrderLine(this.name, this.qty, this.price);
}

class Order {
  final int id;
  final String queueNo;
  final String status;
  final String customer;
  final List<OrderLine> items;
  final String pickupTime;
  final String note;
  final int total;
  final String? cancelReason;
  final DateTime createdAt;

  Order({
    required this.id, required this.queueNo, required this.status, required this.customer, required this.items,
    required this.pickupTime, required this.note, required this.total, this.cancelReason, required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'], queueNo: j['queue_no'], status: j['status'], customer: j['user']['name'],
        items: (j['items'] as List).map((e) => OrderLine(e['name'], e['qty'], e['price'])).toList(),
        pickupTime: j['pickup_time'], note: j['note'] ?? '', total: j['total'], cancelReason: j['cancel_reason'],
        createdAt: DateTime.parse(j['created_at']).toLocal(),
      );
}

class Summary {
  final int orders;
  final int revenue;
  final int cancelled;
  final int inProgress;
  final String? topItem;
  final int topQty;

  Summary({required this.orders, required this.revenue, required this.cancelled, required this.inProgress, this.topItem, this.topQty = 0});

  factory Summary.fromJson(Map<String, dynamic> j) {
    final top = (j['top_items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Summary(
      orders: j['orders'] ?? 0, revenue: j['revenue'] ?? 0, cancelled: j['cancelled'] ?? 0, inProgress: j['in_progress'] ?? 0,
      topItem: top.isEmpty ? null : top.first['name'], topQty: top.isEmpty ? 0 : top.first['qty'],
    );
  }
}

const statusLabel = {
  'pending': 'ออเดอร์ใหม่',
  'accepted': 'รับแล้ว',
  'cooking': 'กำลังทำ',
  'ready': 'พร้อมรับ',
  'completed': 'รับอาหารแล้ว',
  'cancelled': 'ยกเลิก',
};
