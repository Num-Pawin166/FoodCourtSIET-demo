import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  List<MenuItem>? _menu;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await context.read<AppState>().api.menu();
      if (mounted) setState(() { _menu = m; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _toggle(MenuItem m, bool available) async {
    try {
      await context.read<AppState>().api.updateMenu(m.id, {'is_available': available});
      await _load();
      if (mounted) showMsg(context, available ? '${m.name} เปิดขายแล้ว' : '${m.name} ตั้งเป็นหมดแล้ว');
    } catch (e) {
      if (mounted) showMsg(context, e, error: true);
    }
  }

  Future<void> _edit([MenuItem? m]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _MenuForm(item: m),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มเมนู'),
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
          const Text('จัดการเมนู', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const Text('ปิดสวิตช์เมื่อของหมด ลูกค้าจะสั่งเมนูนั้นไม่ได้', style: TextStyle(fontSize: 12, color: AppColors.ink2)),
          const SizedBox(height: 14),
          if (_error != null) Text(_error!, style: const TextStyle(color: AppColors.red)),
          if (_menu == null && _error == null) const Center(child: CircularProgressIndicator(color: AppColors.pink)),
          if (_menu != null && _menu!.isEmpty) const EmptyState(icon: Icons.restaurant_menu, text: 'ยังไม่มีเมนู กด "เพิ่มเมนู" ได้เลย'),
          for (final m in _menu ?? <MenuItem>[]) ...[
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _edit(m),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                  child: Row(children: [
                    Opacity(opacity: m.isAvailable ? 1 : 0.4, child: const FoodImage(width: 56, height: 56)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.name, style: TextStyle(fontWeight: FontWeight.w600, color: m.isAvailable ? AppColors.ink : AppColors.muted)),
                        if (m.description.isNotEmpty)
                          Text(m.description, style: const TextStyle(fontSize: 12, color: AppColors.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(m.isAvailable ? baht(m.price) : '${baht(m.price)} · หมด',
                            style: TextStyle(fontWeight: FontWeight.w600, color: m.isAvailable ? AppColors.accent : AppColors.red, fontSize: 13)),
                      ]),
                    ),
                    Switch(
                      value: m.isAvailable,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppColors.green,
                      onChanged: (v) => _toggle(m, v),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ]),
      ),
    );
  }
}

/// ฟอร์มเพิ่ม/แก้ไขเมนู (bottom sheet) — คืน true เมื่อมีการเปลี่ยนแปลง
class _MenuForm extends StatefulWidget {
  final MenuItem? item;
  const _MenuForm({this.item});

  @override
  State<_MenuForm> createState() => _MenuFormState();
}

class _MenuFormState extends State<_MenuForm> {
  late final _name = TextEditingController(text: widget.item?.name);
  late final _desc = TextEditingController(text: widget.item?.description);
  late final _price = TextEditingController(text: widget.item?.price.toString());
  late bool _available = widget.item?.isAvailable ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final price = int.tryParse(_price.text.trim());
    if (_name.text.trim().isEmpty || price == null) return showMsg(context, 'กรุณากรอกชื่อและราคา (ตัวเลข)', error: true);
    setState(() => _saving = true);
    final api = context.read<AppState>().api;
    final body = {'name': _name.text.trim(), 'description': _desc.text.trim(), 'price': price, 'is_available': _available};
    try {
      widget.item == null ? await api.createMenu(body) : await api.updateMenu(widget.item!.id, body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMsg(context, e, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('ลบเมนู "${widget.item!.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('ยกเลิก')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.red), onPressed: () => Navigator.pop(c, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppState>().api.deleteMenu(widget.item!.id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showMsg(context, e, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.item == null ? 'เพิ่มเมนู' : 'แก้ไขเมนู', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
          if (widget.item != null) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline, color: AppColors.red)),
        ]),
        const SizedBox(height: 12),
        TextField(controller: _name, decoration: const InputDecoration(hintText: 'ชื่อเมนู เช่น ข้าวขาหมู')),
        const SizedBox(height: 10),
        TextField(controller: _desc, decoration: const InputDecoration(hintText: 'รายละเอียด เช่น พร้อมน้ำซุป')),
        const SizedBox(height: 10),
        TextField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'ราคา (บาท)', prefixText: '฿ ')),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('มีขาย'),
          value: _available,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.green,
          onChanged: (v) => setState(() => _available = v),
        ),
        const SizedBox(height: 6),
        PinkButton(onPressed: _save, loading: _saving, child: const Text('บันทึก')),
      ]),
    );
  }
}
