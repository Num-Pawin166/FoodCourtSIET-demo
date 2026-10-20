import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'ai_chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  List<String> _categories = [];
  String _category = '';
  List<Shop>? _shops;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    context.read<AppState>().api.categories().then((c) {
      if (mounted) setState(() => _categories = c);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final shops = await context.read<AppState>().api.shops(q: _search.text.trim(), category: _category);
      if (mounted) setState(() { _shops = shops; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final chips = ['', ..._categories];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, 8), child: FoodCourtLogo(size: 26)),
      const _AiBanner(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: TextField(
          controller: _search,
          onChanged: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), _load);
          },
          decoration: const InputDecoration(
            hintText: 'Search',
            suffixIcon: Icon(Icons.search, color: AppColors.ink2),
            contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 34,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            final selected = chips[i] == _category;
            return ChoiceChip(
              label: Text(chips[i].isEmpty ? 'ทั้งหมด' : chips[i]),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) {
                setState(() => _category = chips[i]);
                _load();
              },
              labelStyle: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.ink),
              selectedColor: AppColors.pink,
              backgroundColor: Colors.white,
              side: BorderSide(color: selected ? AppColors.pink : AppColors.ink2),
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              visualDensity: VisualDensity.compact,
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Expanded(child: RefreshIndicator(color: AppColors.accent, onRefresh: _load, child: _body())),
    ]);
  }

  Widget _body() {
    if (_error != null) {
      return ListView(children: [EmptyState(icon: Icons.wifi_off, text: _error!, action: TextButton(onPressed: _load, child: const Text('ลองใหม่')))]);
    }
    if (_shops == null) return const Center(child: CircularProgressIndicator(color: AppColors.pink));
    if (_shops!.isEmpty) return ListView(children: const [EmptyState(icon: Icons.search_off, text: 'ไม่พบร้านหรือเมนูที่ค้นหา')]);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      itemCount: _shops!.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ShopCard(shop: _shops![i]),
    );
  }
}

/// "วันนี้กินอะไรดี?" → เปิดหน้าผู้ช่วย AI
class _AiBanner extends StatelessWidget {
  const _AiBanner();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('วันนี้กินอะไรดี?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Material(
            color: AppColors.ink,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AiChatScreen())),
              child: const Padding(
                padding: EdgeInsets.fromLTRB(12, 12, 14, 12),
                child: Row(children: [
                  CircleAvatar(radius: 18, backgroundColor: AppColors.pink, child: Icon(Icons.auto_awesome, color: Colors.white, size: 18)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('ถาม AI ช่วยเลือกเมนู', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      Text('บอกงบ เมนูที่อยากกิน ให้ AI แนะนำ', style: TextStyle(color: AppColors.pink, fontSize: 12)),
                    ]),
                  ),
                  Icon(Icons.chevron_right, color: Colors.white),
                ]),
              ),
            ),
          ),
        ]),
      );
}

class _ShopCard extends StatelessWidget {
  final Shop shop;
  const _ShopCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.read<AppState>().openShop(shop.id),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: cardDecoration(),
          child: Row(children: [
            FoodImage(width: 84, height: 84, icon: shop.category == 'เครื่องดื่ม' ? Icons.local_cafe_outlined : shop.category == 'เส้น' ? Icons.ramen_dining_outlined : Icons.rice_bowl_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  _OpenBadge(open: shop.openNow),
                ]),
                const SizedBox(height: 2),
                Text(shop.description, style: const TextStyle(fontSize: 12, color: AppColors.ink2), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  const Icon(Icons.schedule, size: 14, color: AppColors.muted),
                  Text(' ${shop.prepMin}-${shop.prepMax} นาที', style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
                  const SizedBox(width: 12),
                  const Icon(Icons.groups_outlined, size: 14, color: AppColors.muted),
                  Text(' คิว ${shop.queueCount}', style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _OpenBadge extends StatelessWidget {
  final bool open;
  const _OpenBadge({required this.open});

  @override
  Widget build(BuildContext context) => Text(open ? 'เปิดอยู่' : 'ปิดแล้ว',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: open ? AppColors.green : AppColors.red));
}
