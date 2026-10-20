import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

class _Msg {
  final bool fromUser;
  final String text;
  final List<AiPick> picks;
  _Msg(this.fromUser, this.text, [this.picks = const []]);
}

/// ผู้ช่วยแนะนำเมนู (AI by Gemini)
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [
    _Msg(false, 'สวัสดี! บอกงบ เวลาที่อยากได้รับอาหาร หรือสิ่งที่อยากกิน/ไม่กินได้เลย เดี๋ยวช่วยเลือกจากร้านที่เปิดอยู่ให้'),
  ];
  bool _sending = false;

  static const _suggestions = [
    'งบ 50 บาท อยากกินอะไรไม่เผ็ด รับได้ภายใน 12:00',
    'อยากกินเส้น ร้านที่คิวน้อย',
    'เครื่องดื่มเย็นๆ ไม่เกิน 35 บาท',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    setState(() {
      _messages.add(_Msg(true, text));
      _sending = true;
    });
    _scrollToEnd();
    try {
      // ส่งประวัติแชท (ไม่รวมข้อความทักทายแรก) เพื่อให้ AI เข้าใจบริบทต่อเนื่อง
      final history = [
        for (final m in _messages.skip(1)) {'role': m.fromUser ? 'user' : 'assistant', 'text': m.text},
      ];
      final r = await context.read<AppState>().api.aiChat(history);
      if (mounted) setState(() => _messages.add(_Msg(false, r.reply, r.items)));
    } catch (e) {
      if (mounted) setState(() => _messages.add(_Msg(false, 'ขอโทษนะ ตอนนี้ตอบไม่ได้ ($e)')));
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  void _openShop(AiPick p) {
    context.read<AppState>().openShop(p.shopId);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          // หัวหน้าจอ
          Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 10),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: AppColors.line))),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.chevron_left, size: 28), onPressed: () => Navigator.pop(context)),
              const CircleAvatar(radius: 18, backgroundColor: AppColors.pink, child: Icon(Icons.auto_awesome, color: Colors.white, size: 18)),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('ผู้ช่วยแนะนำเมนู', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  Text('AI by Gemini · แนะนำจากร้านที่เปิดอยู่ตอนนี้', style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                for (final m in _messages) _bubble(m),
                if (_messages.length == 1) ...[
                  const SizedBox(height: 8),
                  for (final s in _suggestions)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ActionChip(
                          label: Text(s, style: const TextStyle(fontSize: 12, color: AppColors.accent)),
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.pink),
                          shape: const StadiumBorder(),
                          onPressed: () => _send(s),
                        ),
                      ),
                    ),
                ],
                if (_sending)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('กำลังคิดเมนูให้...', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    ),
                  ),
              ],
            ),
          ),
          // ช่องพิมพ์
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'พิมพ์งบ เวลา หรือสิ่งที่อยากกิน...', counterText: ''),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _bubble(_Msg m) {
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: m.fromUser ? AppColors.accent : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(m.fromUser ? 16 : 4),
          bottomRight: Radius.circular(m.fromUser ? 4 : 16),
        ),
        boxShadow: m.fromUser ? null : cardShadow,
      ),
      child: Text(m.text, style: TextStyle(color: m.fromUser ? Colors.white : AppColors.ink, fontSize: 14)),
    );
    if (m.fromUser) return Align(alignment: Alignment.centerRight, child: bubble);
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        bubble,
        for (final p in m.picks) _pickCard(p),
      ]),
    );
  }

  Widget _pickCard(AiPick p) => Container(
        width: MediaQuery.sizeOf(context).width * 0.78,
        margin: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openShop(p),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.pinkSoft, width: 1.5)),
              child: Row(children: [
                const FoodImage(width: 52, height: 52),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(p.shopName, style: const TextStyle(fontSize: 11, color: AppColors.ink2)),
                    if (p.reason.isNotEmpty) Text(p.reason, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(baht(p.price), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
                  const Text('ไปที่ร้าน ›', style: TextStyle(fontSize: 11, color: AppColors.accent)),
                ]),
              ]),
            ),
          ),
        ),
      );
}
