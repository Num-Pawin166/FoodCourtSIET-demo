import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Shop? _shop;
  final _desc = TextEditingController();
  String _open = '07:30';
  String _close = '17:00';
  int _prepMin = 5;
  int _prepMax = 10;
  bool _isOpen = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _desc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await context.read<AppState>().api.shop();
      if (!mounted) return;
      setState(() {
        _shop = s;
        _desc.text = s.description;
        _open = s.openTime;
        _close = s.closeTime;
        _prepMin = s.prepMin;
        _prepMax = s.prepMax;
        _isOpen = s.isOpen;
      });
    } catch (e) {
      if (mounted) showMsg(context, e, error: true);
    }
  }

  Future<void> _pickTime(bool isOpen) async {
    final cur = (isOpen ? _open : _close).split(':').map(int.parse).toList();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur[0], minute: cur[1]),
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    if (t == null) return;
    final v = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => isOpen ? _open = v : _close = v);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final s = await context.read<AppState>().api.updateShop({
        'description': _desc.text.trim(), 'open_time': _open, 'close_time': _close,
        'prep_min': _prepMin, 'prep_max': _prepMax, 'is_open': _isOpen,
      });
      if (!mounted) return;
      setState(() => _shop = s);
      showMsg(context, 'บันทึกข้อมูลร้านแล้ว');
    } catch (e) {
      if (mounted) showMsg(context, e, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    if (_shop == null) return const Center(child: CircularProgressIndicator(color: AppColors.pink));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      const Text('ร้านของฉัน', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDecoration(),
        child: Row(children: [
          CircleAvatar(radius: 26, backgroundColor: AppColors.pink, child: Text(_shop!.code, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_shop!.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              Text('${_shop!.category} · คิวขึ้นต้นด้วย ${_shop!.code}', style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
              Text('บัญชี ${state.user?.username}', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      _section(Column(children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('เปิดรับออเดอร์', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_isOpen ? 'ลูกค้าสั่งได้ในเวลาทำการ' : 'ร้านปิด ลูกค้าจะสั่งไม่ได้', style: const TextStyle(fontSize: 12)),
          value: _isOpen,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.green,
          onChanged: (v) => setState(() => _isOpen = v),
        ),
        const Divider(color: AppColors.line),
        Row(children: [
          Expanded(child: _timeBox('เวลาเปิด', _open, () => _pickTime(true))),
          const SizedBox(width: 10),
          Expanded(child: _timeBox('เวลาปิด', _close, () => _pickTime(false))),
        ]),
        const SizedBox(height: 12),
        _stepper('เวลารอขั้นต่ำ', _prepMin, (v) => setState(() { _prepMin = v; if (_prepMax < v) _prepMax = v; })),
        _stepper('เวลารอสูงสุด', _prepMax, (v) => setState(() => _prepMax = v < _prepMin ? _prepMin : v)),
      ])),
      const SizedBox(height: 14),
      _section(TextField(
        controller: _desc,
        maxLines: 2,
        maxLength: 300,
        decoration: const InputDecoration(labelText: 'คำอธิบายร้าน (แสดงในแอปนักศึกษา)', counterText: ''),
      )),
      const SizedBox(height: 18),
      PinkButton(onPressed: _save, loading: _saving, child: const Text('บันทึก')),
      const SizedBox(height: 6),
      const Text('ชื่อร้าน หมวดหมู่ และรหัสคิว แก้ไขได้โดยผู้ดูแลศูนย์อาหาร',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: AppColors.muted)),
      const SizedBox(height: 24),
      SizedBox(
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
    ]);
  }

  Widget _section(Widget child) => Container(padding: const EdgeInsets.all(14), decoration: cardDecoration(), child: child);

  Widget _timeBox(String label, String value, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.circular(12)),
          child: Column(children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.ink2)),
            Text('$value น.', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  Widget _stepper(String label, int value, ValueChanged<int> onChanged) => Row(children: [
        Expanded(child: Text(label)),
        QtyButton(icon: Icons.remove, onTap: value > 0 ? () => onChanged(value - 1) : null),
        SizedBox(width: 64, child: Text('$value นาที', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600))),
        QtyButton(icon: Icons.add, filled: true, onTap: value < 120 ? () => onChanged(value + 1) : null),
      ]);
}
