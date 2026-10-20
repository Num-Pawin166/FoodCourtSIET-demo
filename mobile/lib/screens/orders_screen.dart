import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _history = false;
  List<Order>? _orders;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    // อัปเดตสถานะออเดอร์อัตโนมัติทุก 5 วินาที
    _poll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_history) _load();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final history = _history;
    try {
      final list = await context.read<AppState>().api.orders(history: history);
      if (mounted && history == _history) setState(() { _orders = list; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _switch(bool history) {
    if (history == _history) return;
    setState(() { _history = history; _orders = null; });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PageHeader('คำสั่งซื้อ'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _segment('กำลังดำเนินการ', !_history, () => _switch(false)),
            _segment('ประวัติ', _history, () => _switch(true)),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Expanded(child: RefreshIndicator(color: AppColors.accent, onRefresh: _load, child: _body())),
    ]);
  }

  Widget _segment(String label, bool selected, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: selected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(10)),
            child: Text(label, style: TextStyle(color: selected ? AppColors.ink : AppColors.accent, fontWeight: FontWeight.w500)),
          ),
        ),
      );

  Widget _body() {
    if (_error != null && _orders == null) {
      return ListView(children: [EmptyState(icon: Icons.wifi_off, text: _error!, action: TextButton(onPressed: _load, child: const Text('ลองใหม่')))]);
    }
    if (_orders == null) return const Center(child: CircularProgressIndicator(color: AppColors.pink));
    if (_orders!.isEmpty) {
      return ListView(children: [
        EmptyState(
          icon: Icons.receipt_long_outlined,
          text: _history ? 'ยังไม่มีประวัติการสั่งซื้อ' : 'ยังไม่มีออเดอร์ที่กำลังดำเนินการ',
          action: _history ? null : TextButton(onPressed: () => context.read<AppState>().goTab(0), child: const Text('เลือกร้านอาหาร')),
        ),
      ]);
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
      itemCount: _orders!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (_, i) => _history ? _HistoryCard(order: _orders![i]) : _ActiveOrder(order: _orders![i], onChanged: _load),
    );
  }
}

// ---------------- ออเดอร์ที่กำลังดำเนินการ ----------------
class _ActiveOrder extends StatelessWidget {
  final Order order;
  final VoidCallback onChanged;
  const _ActiveOrder({required this.order, required this.onChanged});

  Future<void> _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('ยกเลิกออเดอร์ ${order.queueNo}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ไม่ใช่')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.red), onPressed: () => Navigator.pop(c, true), child: const Text('ยกเลิกออเดอร์')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<AppState>().api.cancelOrder(order.id);
      onChanged();
    } catch (e) {
      if (context.mounted) showMsg(context, e, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = order.status == 'ready';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: cardDecoration(color: ready ? const Color(0xFFE6F6EC) : Colors.white, radius: 20),
        child: Column(children: [
          Text(ready ? 'อาหารพร้อมแล้ว! แสดงหมายเลขนี้ที่ร้าน' : 'หมายเลขคิวสำหรับรับอาหาร',
              style: TextStyle(fontSize: 12, color: ready ? AppColors.green : AppColors.ink2, fontWeight: ready ? FontWeight.w600 : FontWeight.w400)),
          Text(order.queueNo.replaceAll('-', ' - '),
              style: TextStyle(fontSize: 52, fontWeight: FontWeight.w700, color: ready ? AppColors.green : AppColors.accent, height: 1.2)),
          Text(order.shopName, style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: InfoBox('เวลารับอาหาร', '${order.pickupTime} น.')),
            const SizedBox(width: 10),
            Expanded(child: InfoBox('คิวก่อนหน้า', '${order.queueAhead} ออเดอร์')),
          ]),
          const SizedBox(height: 10),
          Text('${order.items.map((i) => '${i.name} ×${i.qty}').join(', ')} · ${baht(order.total)}',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
      ),
      const SizedBox(height: 18),
      const Text('สถานะออเดอร์', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      _Timeline(order: order),
      if (order.status == 'pending')
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _cancel(context),
            icon: const Icon(Icons.close, size: 16, color: AppColors.red),
            label: const Text('ยกเลิกออเดอร์', style: TextStyle(color: AppColors.red)),
          ),
        ),
    ]);
  }
}

class _Timeline extends StatelessWidget {
  final Order order;
  const _Timeline({required this.order});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('ร้านรับออเดอร์', order.acceptedAt, order.status == 'pending' ? 'รอร้านยืนยันออเดอร์...' : null),
      ('กำลังทำอาหาร', order.cookingAt, null),
      ('พร้อมรับอาหาร', order.readyAt, 'แจ้งเตือนเมื่อพร้อม'),
    ];
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 24,
              child: Column(children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: steps[i].$2 != null ? AppColors.accent : Colors.white,
                    border: Border.all(color: steps[i].$2 != null ? AppColors.accent : AppColors.ink2, width: 1.5),
                  ),
                ),
                if (i < steps.length - 1)
                  Expanded(child: Container(width: 2, color: steps[i + 1].$2 != null ? AppColors.accent : AppColors.pink)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(steps[i].$1, style: TextStyle(fontWeight: FontWeight.w500, color: steps[i].$2 != null ? AppColors.ink : AppColors.ink2)),
                  Text(
                    steps[i].$2 != null ? (i == 1 ? 'เริ่ม ${hhmm(steps[i].$2!)} น.' : '${hhmm(steps[i].$2!)} น.') : (steps[i].$3 ?? ''),
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

// ---------------- ประวัติ ----------------
class _HistoryCard extends StatelessWidget {
  final Order order;
  const _HistoryCard({required this.order});

  Future<void> _reorder(BuildContext context) async {
    final state = context.read<AppState>();
    try {
      final missing = await state.reorder(order);
      if (!context.mounted) return;
      if (state.cartCount == 0) return showMsg(context, 'เมนูในออเดอร์นี้หมดแล้วทั้งหมด', error: true);
      if (missing > 0) showMsg(context, 'มี $missing เมนูที่หมดแล้ว ถูกตัดออกจากตะกร้า');
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
    } catch (e) {
      if (context.mounted) showMsg(context, e, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancelled = order.status == 'cancelled';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(order.shopName, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(order.queueNo, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        ]),
        const SizedBox(height: 4),
        Text(order.items.map((i) => '${i.name}x${i.qty}').join(' , '), style: const TextStyle(fontSize: 13, color: AppColors.ink2)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(thaiDateTime(order.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
        ]),
        if (cancelled)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('ยกเลิก: ${order.cancelReason ?? '-'}', style: const TextStyle(fontSize: 12, color: AppColors.red)),
          ),
        const Divider(color: AppColors.ink2, height: 20),
        Row(children: [
          Expanded(child: Text(baht(order.total), style: TextStyle(fontWeight: FontWeight.w700, decoration: cancelled ? TextDecoration.lineThrough : null))),
          OutlinedButton.icon(
            onPressed: () => _reorder(context),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('สั่งอีกครั้ง', style: TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.pink),
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ]),
    );
  }
}
