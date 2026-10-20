import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _stats;
  List<MenuItem>? _favorites;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    try {
      final r = await Future.wait([api.myStats(), api.favorites()]);
      if (!mounted) return;
      setState(() {
        _stats = r[0] as Map<String, dynamic>;
        _favorites = r[1] as List<MenuItem>;
      });
    } catch (e) {
      if (mounted) showMsg(context, e, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user!;
    // ซ่อนรายการที่เพิ่งกดเลิกโปรดทันที
    final favs = _favorites?.where((f) => state.favoriteIds.contains(f.id)).toList();
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.only(bottom: 110), children: [
        const PageHeader('บัญชีของฉัน'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: cardDecoration(),
              child: Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.circular(14)),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: AppColors.accent, width: 1.5)),
                      child: const Icon(Icons.person_outline, color: AppColors.accent, size: 30),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                    Text(user.hasStudentId ? 'รหัสนักศึกษา ${user.username}' : (user.email ?? user.username),
                        style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
                    Text(user.faculty, style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _StatTile('ออเดอร์เดือนนี้', _stats == null ? '-' : '${_stats!['orders_this_month']}')),
              const SizedBox(width: 12),
              Expanded(child: _StatTile('ยอดใช้จ่ายเดือนนี้', _stats == null ? '-' : baht(_stats!['spent_this_month']))),
            ]),
            const SizedBox(height: 20),
            const Text('ร้าน / เมนูโปรด', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            if (favs == null)
              const Center(child: CircularProgressIndicator(color: AppColors.pink))
            else if (favs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('กดรูปหัวใจที่เมนูเพื่อเก็บไว้เป็นเมนูโปรด', style: TextStyle(color: AppColors.muted, fontSize: 13)),
              )
            else
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [for (final f in favs) _FavoriteCard(item: f)],
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: state.logout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.red,
                  side: const BorderSide(color: AppColors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('ออกจากระบบ', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.accent)),
          ),
        ]),
      );
}

class _FavoriteCard extends StatelessWidget {
  final MenuItem item;
  const _FavoriteCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => state.openShop(item.shopId),
        child: Container(
          decoration: cardDecoration(radius: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Stack(children: [
                const Positioned.fill(child: FoodImage()),
                Positioned(
                  right: 4,
                  top: 4,
                  child: GestureDetector(
                    onTap: () => state.toggleFavorite(item.id),
                    child: const Icon(Icons.favorite, color: AppColors.accent, size: 18),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(item.shopName ?? '', style: const TextStyle(fontSize: 11, color: AppColors.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
