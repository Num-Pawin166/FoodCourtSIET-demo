import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// ออเดอร์ของร้าน: แยกตามสถานะ อัปเดตทุก 5 วินาที แจ้งเตือนเมื่อมีออเดอร์ใหม่
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const _filters = ['pending', 'accepted', 'cooking', 'ready', 'today'];
  String _filter = 'pending';

  Shop? _shop;
  Summary? _summary;
  List<Order> _active = [];
  List<Order>? _today;
  Set<int>? _seenPending; // null = ยังไม่โหลดครั้งแรก (ไม่ต้องแจ้งเตือน)
  final Set<int> _highlight = {};
  String? _error;
  Timer? _poll;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    try {
      final r = await Future.wait([
        api.shop(),
        api.summary(),
        api.orders(),
        if (_filter == 'today') api.orders(today: true),
      ]);
      if (!mounted) return;
      final active = r[2] as List<Order>;
      final pendingIds = active.where((o) => o.status == 'pending').map((o) => o.id).toSet();
      final fresh = _seenPending == null ? <int>{} : pendingIds.difference(_seenPending!);
      if (fresh.isNotEmpty) _alertNew(active.where((o) => fresh.contains(o.id)).toList());
      setState(() {
        _shop = r[0] as Shop;
        _summary = r[1] as Summary;
        _active = active;
        if (r.length > 3) _today = r[3] as List<Order>;
        _seenPending = pendingIds;
        _highlight.addAll(fresh);
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _alertNew(List<Order> orders) {
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    showMsg(context, '🔔 ออเดอร์ใหม่ ${orders.map((o) => o.queueNo).join(', ')}');
  }

  Future<void> _setStatus(Order o, String status) async {
    String? reason;
    if (status == 'cancelled') {
      reason = await _askReason(o);
      if (reason == null || !mounted) return;
    }
    setState(() => _busy.add(o.id));
    try {
      await context.read<AppState>().api.setStatus(o.id, status, reason: reason);
      _highlight.remove(o.id);
      await _load();
    } catch (e) {
      if (mounted) showMsg(context, e, error: true);
    } finally {
      if (mounted) setState(() => _busy.remove(o.id));
    }
  }

  Future<String?> _askReason(Order o) {
    final ctrl = TextEditingController(text: 'วัตถุดิบหมด');
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('ยกเลิกออเดอร์ ${o.queueNo}'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'เหตุผล (ลูกค้าจะเห็น)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('ไม่ยกเลิก')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(c, ctrl.text.trim().isEmpty ? 'ร้านยกเลิกออเดอร์' : ctrl.text.trim()),
            child: const Text('ยืนยันยกเลิก'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleOpen(bool open) async {
    try {
      final s = await context.read<AppState>().api.updateShop({'is_open': open});
      if (!mounted) return;
      setState(() => _shop = s);
      showMsg(context, open ? 'เปิดรับออเดอร์แล้ว' : 'ปิดรับออเดอร์แล้ว');
    } catch (e) {
      if (mounted) showMsg(context, e, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shop == null) {
      return _error != null
          ? EmptyState(icon: Icons.wifi_off, text: _error!, action: TextButton(onPressed: _load, child: const Text('ลองใหม่')))
          : const Center(child: CircularProgressIndicator(color: AppColors.pink));
    }
    final count = {for (final f in _filters) f: _active.where((o) => o.status == f).length};
    final list = _filter == 'today' ? (_today ?? []) : _active.where((o) => o.status == _filter).toList();

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ออเดอร์', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              Text('${_shop!.name} · คิว ${_shop!.code}', style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
            ]),
          ),
          Column(children: [
            Switch(value: _shop!.isOpen, activeThumbColor: Colors.white, activeTrackColor: AppColors.green, onChanged: _toggleOpen),
            Text(_shop!.isOpen ? 'เปิดรับ' : 'ปิดร้าน',
                style: TextStyle(fontSize: 11, color: _shop!.isOpen ? AppColors.green : AppColors.red, fontWeight: FontWeight.w600)),
          ]),
        ]),
        if (_error != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('⚠ $_error', style: const TextStyle(color: AppColors.red, fontSize: 12))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _Tile('ออเดอร์วันนี้', '${_summary?.orders ?? 0}')),
          const SizedBox(width: 8),
          Expanded(child: _Tile('ยอดขายวันนี้', baht(_summary?.revenue ?? 0))),
          const SizedBox(width: 8),
          Expanded(child: _Tile('รอทำ', '${_summary?.inProgress ?? 0}')),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 38,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            for (final f in _filters)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(f == 'today' ? 'ทั้งหมดวันนี้' : '${statusLabel[f]} ${count[f]}'),
                  selected: _filter == f,
                  showCheckmark: false,
                  selectedColor: AppColors.pink,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(fontSize: 13, color: _filter == f ? Colors.white : AppColors.ink, fontWeight: FontWeight.w500),
                  side: BorderSide(color: f == 'pending' && count[f]! > 0 ? AppColors.accent : AppColors.line),
                  shape: const StadiumBorder(),
                  onSelected: (_) {
                    setState(() => _filter = f);
                    if (f == 'today') _load();
                  },
                ),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: EmptyState(icon: Icons.inbox_outlined, text: 'ไม่มีออเดอร์ในหมวดนี้'),
          )
        else
          for (final o in list) ...[
            _OrderCard(
              order: o,
              highlight: _highlight.contains(o.id),
              busy: _busy.contains(o.id),
              onStatus: (s) => _setStatus(o, s),
            ),
            const SizedBox(height: 12),
          ],
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  const _Tile(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.ink2)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.accent)),
          ),
        ]),
      );
}

class _OrderCard extends StatelessWidget {
  final Order order;
  final bool highlight;
  final bool busy;
  final void Function(String status) onStatus;
  const _OrderCard({required this.order, required this.highlight, required this.busy, required this.onStatus});

  static const _actions = {
    'pending': [('accepted', 'รับออเดอร์'), ('cancelled', 'ปฏิเสธ')],
    'accepted': [('cooking', 'เริ่มทำ'), ('cancelled', 'ยกเลิก')],
    'cooking': [('ready', 'ทำเสร็จแล้ว')],
    'ready': [('completed', 'ลูกค้ารับแล้ว')],
  };

  @override
  Widget build(BuildContext context) {
    final actions = _actions[order.status] ?? const [];
    final done = order.status == 'completed' || order.status == 'cancelled';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFF4F7) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: highlight ? AppColors.accent : AppColors.pink, width: 5)),
        boxShadow: cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(order.queueNo, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.accent)),
          if (highlight) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(99)),
              child: const Text('ใหม่', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ],
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.circular(99)),
            child: Text('รับ ${order.pickupTime} น.', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
        Text('${order.customer} · สั่งเมื่อ ${hhmm(order.createdAt)} น.${done ? ' · ${statusLabel[order.status]}' : ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 8),
        for (final i in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(children: [
              Text('${i.qty}×', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent)),
              const SizedBox(width: 8),
              Expanded(child: Text(i.name, style: const TextStyle(fontSize: 15))),
            ]),
          ),
        if (order.note.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(8)),
            child: Text('📝 ${order.note}', style: const TextStyle(color: Color(0xFFA86400), fontSize: 13)),
          ),
        if (order.cancelReason != null && order.status == 'cancelled')
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('ยกเลิก: ${order.cancelReason}', style: const TextStyle(color: AppColors.red, fontSize: 12)),
          ),
        const SizedBox(height: 10),
        Row(children: [
          Text(baht(order.total), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (busy)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.pink))
          else
            for (final (status, label) in actions) ...[
              const SizedBox(width: 8),
              status == 'cancelled'
                  ? TextButton(
                      onPressed: () => onStatus(status),
                      style: TextButton.styleFrom(foregroundColor: AppColors.red),
                      child: Text(label),
                    )
                  : FilledButton(
                      onPressed: () => onStatus(status),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.accent, shape: const StadiumBorder()),
                      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
            ],
        ]),
      ]),
    );
  }
}
