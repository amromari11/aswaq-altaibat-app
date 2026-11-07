import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/external_launcher.dart';
import '../../../../core/utils/jordan_phone.dart';
import '../../data/repositories/driver_repository.dart';
import '../../domain/entities/driver_order.dart';
import '../providers/driver_providers.dart';

/// One assigned order: who, where, how much, and the four driver actions.
class DriverOrderCard extends ConsumerStatefulWidget {
  const DriverOrderCard({super.key, required this.order});

  final DriverOrder order;

  static ValueKey<String> pickUpKey(String id) => ValueKey('driver-pickup-$id');
  static ValueKey<String> deliveredKey(String id) => ValueKey('driver-delivered-$id');
  static ValueKey<String> mapsKey(String id) => ValueKey('driver-maps-$id');
  static ValueKey<String> callKey(String id) => ValueKey('driver-call-$id');

  @override
  ConsumerState<DriverOrderCard> createState() => _DriverOrderCardState();
}

class _DriverOrderCardState extends ConsumerState<DriverOrderCard> {
  bool _busy = false;

  DriverOrder get _order => widget.order;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _open(Uri uri) async {
    final ok = await ref.read(externalLauncherProvider)(uri);
    if (!ok) _snack('تعذر فتح التطبيق على هذا الجهاز.');
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on DriverActionException catch (e) {
      _snack(e.messageAr);
    } catch (_) {
      _snack('تعذّر الاتصال، تحقق من الإنترنت وحاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickUp() => _run(() async {
        await ref.read(driverOrdersProvider.notifier).pickUp(_order.id);
        _snack('تم استلام الطلب ${_order.code} — بالتوفيق في التوصيل!');
      });

  Future<void> _deliver() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تأكيد تسليم ${_order.code}'),
        content: Text(
          _order.isCash && _order.total > 0
              ? 'تأكد من استلام ${CurrencyFormatter.jod(_order.total)} نقداً من الزبون قبل التأكيد.'
              : 'هل سلّمت الطلب للزبون؟',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تم التسليم'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final result = await ref.read(driverOrdersProvider.notifier).markDelivered(_order.id);
      _snack(result.pointsAwarded > 0
          ? 'تم التسليم ✓ — أُضيفت ${result.pointsAwarded} نقطة لحساب الزبون'
          : 'تم التسليم ✓');
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final phone = order.customerPhone;
    final time = DateFormat('HH:mm').format(order.scheduledTime ?? order.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: order.isPickedUp ? AppColors.accent.withValues(alpha: 0.45) : AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.06), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(order.code, textDirection: TextDirection.ltr, style: AppTextStyles.h3),
              const SizedBox(width: 10),
              _StatusChip(order: order),
              const Spacer(),
              Icon(order.scheduledTime != null ? Icons.event : Icons.schedule, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(order.scheduledTime != null ? 'مجدول $time' : time, style: AppTextStyles.caption),
            ],
          ),
          const Divider(height: 24),
          _InfoRow(icon: Icons.person_outline, text: order.customerName?.trim().isNotEmpty == true ? order.customerName!.trim() : 'زبون'),
          if (phone != null)
            _InfoRow(icon: Icons.phone_outlined, text: JordanPhone.toLocal(phone), ltr: true),
          _InfoRow(
            icon: Icons.location_on_outlined,
            text: order.zoneName == null ? order.deliveryAddress : '${order.deliveryAddress} — ${order.zoneName}',
          ),
          if (order.notes != null && order.notes!.trim().isNotEmpty)
            _InfoRow(icon: Icons.sticky_note_2_outlined, text: order.notes!.trim(), muted: true),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: AppColors.canvas, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الإجمالي (${order.itemCount} قطعة)', style: AppTextStyles.caption),
                      Text(CurrencyFormatter.jod(order.total), style: AppTextStyles.price),
                    ],
                  ),
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('طريقة الدفع', style: AppTextStyles.caption),
                      Text(
                        order.paymentMethodAr,
                        textAlign: TextAlign.end,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (order.pointsRedeemed > 0)
                        Text(
                          '+ ${order.pointsRedeemed} نقطة من رصيده',
                          textAlign: TextAlign.end,
                          style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Full-width rows: big targets for a driver on the move, and the
          // labels never truncate on a narrow phone.
          OutlinedButton.icon(
            key: DriverOrderCard.mapsKey(order.id),
            onPressed: () => _open(order.mapsUri),
            icon: const Icon(Icons.map_outlined, size: 20),
            label: const Text('فتح الموقع على Google Maps'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: DriverOrderCard.callKey(order.id),
            onPressed: order.callUri == null ? null : () => _open(order.callUri!),
            icon: const Icon(Icons.call_outlined, size: 20),
            label: const Text('اتصال بالزبون'),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: order.isPickedUp
                ? FilledButton.icon(
                    key: DriverOrderCard.deliveredKey(order.id),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                    onPressed: _busy ? null : _deliver,
                    icon: _busy ? const _Spinner() : const Icon(Icons.check_circle_outline),
                    label: const Text('تم التسليم'),
                  )
                : FilledButton.icon(
                    key: DriverOrderCard.pickUpKey(order.id),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                    onPressed: _busy ? null : _pickUp,
                    icon: _busy ? const _Spinner() : const Icon(Icons.delivery_dining),
                    label: const Text('استلام الطلب'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.order});

  final DriverOrder order;

  @override
  Widget build(BuildContext context) {
    final onRoad = order.isPickedUp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: onRoad ? AppColors.accent.withValues(alpha: 0.1) : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        order.status.labelAr,
        style: AppTextStyles.caption.copyWith(
          color: onRoad ? AppColors.accent : AppColors.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.ltr = false, this.muted = false});

  final IconData icon;
  final String text;
  final bool ltr;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textDirection: ltr ? TextDirection.ltr : null,
              // An LTR run (a phone number) still lines up with the RTL rows.
              textAlign: ltr ? TextAlign.end : TextAlign.start,
              style: (muted ? AppTextStyles.caption : AppTextStyles.body).copyWith(
                color: muted ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
}
