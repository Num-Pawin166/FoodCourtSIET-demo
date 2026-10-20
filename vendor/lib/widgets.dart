import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme.dart';

String baht(int n) {
  final s = n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '฿$s';
}

const _thMonths = ['ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
String hhmm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

/// 16 ต.ค. 2569 11.15 น.
String thaiDateTime(DateTime d) => '${d.day} ${_thMonths[d.month - 1]} ${d.year + 543} ${hhmm(d)} น.';

void showMsg(BuildContext context, Object msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg.toString()),
      backgroundColor: error ? AppColors.red : AppColors.ink,
    ));
}

/// โลโก้ "Food Court" สีชมพู + ตรา KMITL
class FoodCourtLogo extends StatelessWidget {
  final double size;
  const FoodCourtLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    TextStyle style(Color c, {Paint? fg}) => GoogleFonts.fredoka(
          fontSize: size, height: 0.85, fontWeight: FontWeight.w700, color: fg == null ? c : null, foreground: fg);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size / 7
      ..color = Colors.white;
    Widget word(String t) => Stack(children: [Text(t, style: style(Colors.white, fg: stroke)), Text(t, style: style(AppColors.pink))]);
    return SizedBox(
      width: size * 3.4,
      child: Stack(clipBehavior: Clip.none, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          word('Food'),
          Padding(padding: EdgeInsets.only(left: size * 0.35), child: word('Court')),
          if (size >= 40)
            Padding(
              padding: EdgeInsets.only(left: size * 1.5, top: 2),
              child: Text('SIET', style: TextStyle(fontSize: size * 0.22, color: AppColors.pink, fontWeight: FontWeight.w700, letterSpacing: 2)),
            ),
        ]),
        Positioned(
          right: 0,
          top: size * 0.55,
          child: Container(
            width: size * 0.75,
            height: size * 0.75,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.kmitl, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            child: Text('KMITL', style: TextStyle(color: Colors.white, fontSize: size * 0.16, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

/// หัวหน้าจอ: ชื่อหน้าด้านซ้าย โลโก้ด้านขวา
class PageHeader extends StatelessWidget {
  final String title;
  const PageHeader(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600))),
          const FoodCourtLogo(size: 22),
        ]),
      );
}

/// รูปอาหาร (ยังไม่มีรูปจริง ใช้กล่องสีชมพูอ่อน + ไอคอน)
class FoodImage extends StatelessWidget {
  final double width;
  final double height;
  final IconData icon;
  const FoodImage({super.key, this.width = 72, this.height = 72, this.icon = Icons.rice_bowl_outlined});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppColors.pink, size: (height * 0.4).clamp(18, 48)),
      );
}

class QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  const QtyButton({super.key, required this.icon, this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) => InkResponse(
        onTap: onTap,
        radius: 20,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? (onTap == null ? AppColors.pinkSoft : AppColors.pink) : Colors.white,
            border: Border.all(color: AppColors.pink, width: 1.5),
          ),
          child: Icon(icon, size: 16, color: filled ? Colors.white : AppColors.accent),
        ),
      );
}

/// ปุ่มหลักสีชมพูทรงแคปซูล
class PinkButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool loading;
  const PinkButton({super.key, required this.child, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.pink,
            disabledBackgroundColor: AppColors.pinkSoft,
            foregroundColor: Colors.white,
            shape: const StadiumBorder(),
            textStyle: GoogleFonts.prompt(fontSize: 16, fontWeight: FontWeight.w600),
            elevation: 3,
            shadowColor: AppColors.accent.withValues(alpha: 0.3),
          ),
          onPressed: loading ? null : onPressed,
          child: loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : child,
        ),
      );
}

class InfoBox extends StatelessWidget {
  final String label;
  final String value;
  const InfoBox(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(color: AppColors.pinkSoft, borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.ink2), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 56, color: AppColors.pink),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.ink2)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}
