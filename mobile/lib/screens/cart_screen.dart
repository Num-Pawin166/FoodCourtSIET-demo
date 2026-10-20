import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final TextEditingController _note;
  List<String>? _slots;
  String? _slot;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _note = TextEditingController(text: state.cartNote);
    _loadSlots();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadSlots() async {
    final state = context.read<AppState>();
    if (state.cartShop == null) return;
    try {
      final slots = await state.api.slots(state.cartShop!.id);
      if (!mounted) return;
      setState(() {
        _slots = slots;
        if (!slots.contains(_slot)) _slot = slots.isEmpty ? null : slots.first;
      });
    } catch (e) {
      if (mounted) showMsg(context, e, error: true);
    }
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    if (_slot == null) return showMsg(context, 'กรุณาเลือกเวลารับอาหาร', error: true);
    setState(() => _submitting = true);
    try {
      final order = await state.api.createOrder(
        shopId: state.cartShop!.id,
        items: Map.of(state.cartQty),
        pickupTime: _slot!,
        note: _note.text.trim(),
      );
      state.clearCart();
      state.goTab(2);
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      showMsg(context, 'สั่งอาหารสำเร็จ! หมายเลขคิว ${order.queueNo}');
    } catch (e) {
      if (!mounted) return;
      showMsg(context, e, error: true);
      _loadSlots(); // เวลาที่เลือกอาจหมดแล้ว
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final shop = state.cartShop;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 20, 4),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left, size: 28), onPressed: () => Navigator.pop(context)),
              const Text('ตะกร้าของฉัน', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
            ]),
          ),
          Expanded(
            child: shop == null
                ? const EmptyState(icon: Icons.shopping_basket_outlined, text: 'ตะกร้าว่าง')
                : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
                    _itemsCard(state),
                    const SizedBox(height: 22),
                    const Text('เลือกเวลารับอาหาร', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    _slotGrid(),
                    const SizedBox(height: 22),
                    const Text('หมายเหตุถึงร้าน', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Container(
                      decoration: cardDecoration(),
                      child: TextField(
                        controller: _note,
                        maxLength: 200,
                        maxLines: 2,
                        onChanged: (v) => state.cartNote = v,
                        decoration: InputDecoration(
                          hintText: 'เช่น แยกน้ำซุป , ไม่ใส่ผักดอง',
                          counterText: '',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _summary(state),
                  ]),
          ),
          if (shop != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: PinkButton(
                loading: _submitting,
                onPressed: _slot == null ? null : _submit,
                child: Text('ยืนยันคำสั่งซื้อ  ${baht(state.cartTotal)}'),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _itemsCard(AppState state) => Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(state.cartShop!.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final (item, qty) in state.cartLines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.circular(8)),
                  child: Text('$qty×', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(item.name, style: const TextStyle(fontSize: 14))),
                Text(baht(item.price * qty), style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                QtyButton(icon: Icons.remove, onTap: () => state.setQty(state.cartShop!, item, qty - 1)),
                const SizedBox(width: 6),
                QtyButton(icon: Icons.add, filled: true, onTap: qty < 20 ? () => state.setQty(state.cartShop!, item, qty + 1) : null),
              ]),
            ),
          const Divider(color: AppColors.line),
          InkWell(
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 2),
              child: Text('+ เพิ่มเมนู', style: TextStyle(color: AppColors.pink, fontSize: 13)),
            ),
          ),
        ]),
      );

  Widget _slotGrid() {
    if (_slots == null) return const Center(child: CircularProgressIndicator(color: AppColors.pink));
    if (_slots!.isEmpty) {
      return const Text('วันนี้ร้านไม่มีช่วงเวลาให้รับอาหารแล้ว', style: TextStyle(color: AppColors.red));
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.8,
      children: [
        for (final s in _slots!)
          GestureDetector(
            onTap: () => setState(() => _slot = s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s == _slot ? AppColors.pink : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: cardShadow,
              ),
              child: Text(s, style: TextStyle(color: s == _slot ? Colors.white : AppColors.ink, fontWeight: FontWeight.w500)),
            ),
          ),
      ],
    );
  }

  Widget _summary(AppState state) {
    Widget line(String a, String b, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Expanded(child: Text(a, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w600 : FontWeight.w400, color: bold ? AppColors.ink : AppColors.ink2))),
            Text(b, style: TextStyle(fontSize: bold ? 15 : 13, fontWeight: bold ? FontWeight.w700 : FontWeight.w500, color: bold ? AppColors.accent : AppColors.ink)),
          ]),
        );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(children: [
        line('รวม ${state.cartCount} รายการ', baht(state.cartTotal)),
        line('รับอาหารเวลา', _slot == null ? '-' : '$_slot น.'),
        const Divider(color: AppColors.ink2, height: 18),
        line('ยอดชำระ', baht(state.cartTotal), bold: true),
        const SizedBox(height: 4),
        const Text('ชำระเงินที่ร้านตอนรับอาหาร', style: TextStyle(fontSize: 11, color: AppColors.muted)),
      ]),
    );
  }
}
