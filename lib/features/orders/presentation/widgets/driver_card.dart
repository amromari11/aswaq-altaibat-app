import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/external_launcher.dart';
import '../../../../core/utils/jordan_phone.dart';

/// Who is bringing the order, with call and WhatsApp buttons.
///
/// Uses the driver's own number when the shop entered one; otherwise the
/// buttons reach the shop ([storePhone]) and say so. With no number at all the
/// card still shows that the order is on its way.
class DriverCard extends ConsumerWidget {
  const DriverCard({super.key, this.name, this.driverPhone, this.storePhone});

  final String? name;

  /// E.164 (+962791112233).
  final String? driverPhone;

  /// The shop's number, as typed in the store settings (e.g. 0791112222).
  final String? storePhone;

  static const callKey = ValueKey('driver-call');
  static const chatKey = ValueKey('driver-chat');

  /// '+962791112233' for either spelling, or null when it isn't a Jordanian mobile.
  static String? _e164(String? raw) => raw == null ? null : JordanPhone.normalize(raw);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = _e164(driverPhone);
    final shop = _e164(storePhone);
    final phone = driver ?? shop;
    final usingShop = driver == null && shop != null;
    final hasName = name != null && name!.trim().isNotEmpty;
    final launch = ref.read(externalLauncherProvider);

    Future<void> open(Uri uri) async {
      final ok = await launch(uri);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح التطبيق على هذا الجهاز.')));
      }
    }

    final subtitle = usingShop
        ? 'للتواصل اتصل بالمتجر'
        : (phone != null ? JordanPhone.toLocal(phone) : 'في طريقه إليك');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: hasName
                ? Text(_initials(name!), style: AppTextStyles.bodyMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w800))
                : const Icon(Icons.delivery_dining, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? name!.trim() : 'سائق التوصيل',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800),
                ),
                Text(
                  subtitle,
                  textDirection: (!usingShop && phone != null) ? TextDirection.ltr : null,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (phone != null) ...[
            _RoundButton(
              key: chatKey,
              icon: Icons.chat_bubble_outline,
              tooltip: usingShop ? 'مراسلة المتجر على واتساب' : 'مراسلة السائق على واتساب',
              onTap: () => open(Uri.https('wa.me', '/${phone.substring(1)}')),
            ),
            const SizedBox(width: 8),
            _RoundButton(
              key: callKey,
              icon: Icons.call,
              filled: true,
              tooltip: usingShop ? 'الاتصال بالمتجر' : 'الاتصال بالسائق',
              onTap: () => open(Uri(scheme: 'tel', path: phone)),
            ),
          ],
        ],
      ),
    );
  }

  /// First letters of the first two words ('خالد أحمد' -> 'خأ').
  static String _initials(String name) {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '؟';
    final letters = words.take(2).map((w) => String.fromCharCode(w.runes.first)).join();
    return letters;
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({super.key, required this.icon, required this.tooltip, required this.onTap, this.filled = false});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? AppColors.primary : Colors.white,
            border: Border.all(color: filled ? AppColors.primary : AppColors.border),
          ),
          child: Icon(icon, size: 20, color: filled ? Colors.white : AppColors.primary),
        ),
      ),
    );
  }
}
