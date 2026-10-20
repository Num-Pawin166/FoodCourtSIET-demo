import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'cart_screen.dart';

class ShopMenuScreen extends StatefulWidget {
  final int? shopId;
  const ShopMenuScreen({super.key, required this.shopId});

  @override
  State<ShopMenuScreen> createState() => _ShopMenuScreenState();
}

class _ShopMenuScreenState extends State<ShopMenuScreen> {
  Shop? _shop;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.shopId ?? context.read<AppState>().cartShop?.id;
    if (id == null) return;
    try {
      final s = await context.read<AppState>().api.shop(id);
      if (mounted) setState(() { _shop = s; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _changeQty(MenuItem item, int qty) async {
    final state = context.read<AppState>();
    if (state.isOtherShop(_shop!)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('เริ่มตะกร้าใหม่?'),
          content: Text('ตะกร้ามีเมนูจาก "${state.cartShop!.name}" อยู่ สั่งได้ทีละร้าน ต้องการล้างตะกร้าเดิมไหม'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('ล้างตะกร้า')),
          ],
        ),
      );
      if (ok != true) return;
    }
    state.setQty(_shop!, item, qty);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (widget.shopId == null && state.cartShop == null) {
      return EmptyState(
        icon: Icons.storefront_outlined,
        text: 'ยังไม่ได้เลือกร้าน\nเลือกร้านจากหน้า Home ได้เลย',
        action: FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.pink), onPressed: () => state.goTab(0), child: const Text('ไปหน้า Home')),
      );
    }
    if (_error != null) return EmptyState(icon: Icons.wifi_off, text: _error!, action: TextButton(onPressed: _load, child: const Text('ลองใหม่')));
    if (_shop == null) return const Center(child: CircularProgressIndicator(color: AppColors.pink));

    final shop = _shop!;
    final inThisShop = state.cartShop?.id == shop.id;
    return Stack(children: [
      RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _load,
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _Header(shop: shop)),
          const SliverToBoxAdapter(
            child: Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, 8), child: Text('เมนูและราคา', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 190),
            sliver: SliverList.separated(
              itemCount: shop.menu.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                final m = shop.menu[i];
                final qty = inThisShop ? state.qtyOf(m.id) : 0;
                final canOrder = shop.openNow && m.isAvailable;
                return Opacity(
                  opacity: m.isAvailable ? 1 : 0.5,
                  child: Row(children: [
                    Stack(children: [
                      const FoodImage(width: 76, height: 66),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: GestureDetector(
                          onTap: () => state.toggleFavorite(m.id).catchError((e) { if (context.mounted) showMsg(context, e, error: true); }),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(state.favoriteIds.contains(m.id) ? Icons.favorite : Icons.favorite_border, size: 18, color: AppColors.accent),
                          ),
                        ),
                      ),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (m.description.isNotEmpty)
                          Text(m.description, style: const TextStyle(fontSize: 11, color: AppColors.ink2), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(m.isAvailable ? baht(m.price) : 'หมดแล้ว',
                            style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 13)),
                      ]),
                    ),
                    QtyButton(icon: Icons.remove, onTap: qty > 0 ? () => _changeQty(m, qty - 1) : null),
                    SizedBox(width: 30, child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                    QtyButton(icon: Icons.add, filled: true, onTap: canOrder ? () => _changeQty(m, qty + 1) : null),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
      if (inThisShop && state.cartCount > 0)
        Positioned(
          left: 16,
          right: 16,
          bottom: 104,
          child: Material(
            color: AppColors.pink,
            shape: const StadiumBorder(),
            elevation: 4,
            shadowColor: AppColors.accent.withValues(alpha: 0.4),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Row(children: [
                  CircleAvatar(radius: 14, backgroundColor: Colors.white, child: Text('${state.cartCount}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 13))),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('เพิ่มลงตะกร้า', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16))),
                  Text(baht(state.cartTotal), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(width: 8),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _Header extends StatelessWidget {
  final Shop shop;
  const _Header({required this.shop});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Container(
        height: 120,
        decoration: const BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.vertical(bottom: Radius.circular(24))),
        child: const Center(child: Padding(padding: EdgeInsets.only(bottom: 30), child: Icon(Icons.soup_kitchen_outlined, size: 44, color: AppColors.ink))),
      ),
      Positioned(
        left: 12,
        top: 8,
        child: IconButton.filled(
          style: IconButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.ink),
          icon: const Icon(Icons.chevron_left),
          onPressed: () => context.read<AppState>().goTab(0),
        ),
      ),
      Container(
        margin: const EdgeInsets.fromLTRB(16, 90, 16, 0),
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
            Text(shop.openNow ? 'เปิดอยู่' : 'ปิดแล้ว',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: shop.openNow ? AppColors.green : AppColors.red)),
          ]),
          const SizedBox(height: 4),
          Text(shop.description, style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: InfoBox('เวลาเปิด-ปิด', '${shop.openTime} - ${shop.closeTime}')),
            const SizedBox(width: 8),
            Expanded(child: InfoBox('รอประมาณ', '${shop.prepMin}-${shop.prepMax} นาที')),
            const SizedBox(width: 8),
            Expanded(child: InfoBox('คิวตอนนี้', '${shop.queueCount} ออเดอร์')),
          ]),
        ]),
      ),
    ]);
  }
}
