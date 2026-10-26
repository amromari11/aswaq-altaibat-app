import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/order_ref.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/order_tracking.dart';
import '../providers/order_providers.dart';
import '../widgets/order_map.dart';
import '../widgets/order_stepper.dart';

/// Live tracking for one order. Opened right after checkout and from the
/// orders list; works for guests (the [OrderRef] token is the key) and keeps
/// itself current via Realtime (see [orderTrackingProvider]).
class OrderTrackingPage extends ConsumerWidget {
  const OrderTrackingPage({super.key, required this.orderRef});

  final OrderRef orderRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(orderTrackingProvider(orderRef));
    final canGoBack = context.canPop();

    return Scaffold(
      appBar: AppBar(
        title: Text('تتبع الطلب ${orderRef.displayCode}'),
        // After checkout this screen replaces the cart/checkout stack, so
        // there may be nothing to pop: offer Home instead of a dead back arrow.
        leading: canGoBack
            ? null
            : IconButton(
                icon: const Icon(Icons.home_outlined),
                tooltip: 'الرئيسية',
                onPressed: () => context.go('/home'),
              ),
      ),
      body: tracking.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Message(
          icon: Icons.wifi_off,
          title: 'تعذر تحميل حالة الطلب',
          detail: 'تحقق من الاتصال بالإنترنت وحاول مرة أخرى.',
          actionLabel: 'إعادة المحاولة',
          onAction: () => ref.invalidate(orderTrackingProvider(orderRef)),
        ),
        data: (order) => order == null
            ? const _Message(
                icon: Icons.search_off,
                title: 'لم نجد هذا الطلب',
                detail: 'قد يكون الرابط غير صحيح. يمكنك الاطلاع على طلباتك من صفحة «طلباتي».',
              )
            : _Content(order: order, code: orderRef.code),
      ),
    );
  }
}

/// A driver position older than this is flagged as possibly out of date.
const _driverStaleAfter = Duration(minutes: 3);

class _Content extends StatelessWidget {
  const _Content({required this.order, required this.code});

  final OrderTracking order;
  final String code;

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final showMap = status != OrderStatus.cancelled;
    // About a third of the screen, never cramped and never taking over.
    final mapHeight = (MediaQuery.sizeOf(context).height * 0.30).clamp(190.0, 300.0);

    return Column(
      children: [
        if (showMap) ...[
          // Fixed above the list (not inside it) so dragging the map never
          // fights with scrolling the page.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(height: mapHeight, child: _TrackingMap(order: order)),
          ),
          _MapCaption(order: order),
        ],
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _StatusHeader(order: order),
              const SizedBox(height: 16),
              if (status == OrderStatus.cancelled)
                const _CancelledNotice()
              else
                _Card(
                  title: 'مراحل الطلب',
                  child: OrderStepper(status: status),
                ),
              const SizedBox(height: 16),
              _Card(
                title: 'تفاصيل التوصيل',
                child: Column(
                  children: [
                    _DetailRow(icon: Icons.location_on_outlined, label: 'العنوان', value: order.deliveryAddress),
                    if (order.zoneName != null)
                      _DetailRow(icon: Icons.map_outlined, label: 'منطقة التوصيل', value: order.zoneName!),
                    if (order.etaMinutes != null)
                      _DetailRow(
                        icon: Icons.schedule,
                        label: 'الوقت المتوقع',
                        value: 'حوالي ${order.etaMinutes} دقيقة من وقت الطلب',
                      ),
                    const _DetailRow(icon: Icons.payments_outlined, label: 'الدفع', value: 'نقداً عند الاستلام'),
                    if ((order.notes ?? '').trim().isNotEmpty)
                      _DetailRow(icon: Icons.sticky_note_2_outlined, label: 'ملاحظاتك', value: order.notes!.trim()),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Card(title: 'ملخص الطلب', child: _Summary(order: order)),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('العودة للرئيسية'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => context.go('/orders'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('طلباتي'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// What the driver marker should show for [order]: their real position when
/// they've shared one, otherwise — once the order has left the store — the
/// store itself (greyed, so it isn't mistaken for a live fix).
({LatLng point, bool stale, bool assumed})? _driverOnMap(OrderTracking order) {
  if (order.status != OrderStatus.outForDelivery) return null;
  final driver = order.driver;
  if (driver == null) {
    return (point: const LatLng(AppConfig.storeLatitude, AppConfig.storeLongitude), stale: true, assumed: true);
  }
  final old = DateTime.now().difference(driver.updatedAt) > _driverStaleAfter;
  return (point: LatLng(driver.latitude, driver.longitude), stale: old, assumed: false);
}

class _TrackingMap extends ConsumerWidget {
  const _TrackingMap({required this.order});

  final OrderTracking order;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = _driverOnMap(order);
    return OrderMap(
      store: const LatLng(AppConfig.storeLatitude, AppConfig.storeLongitude),
      home: order.hasDeliveryPin ? LatLng(order.deliveryLat!, order.deliveryLng!) : null,
      driver: driver?.point,
      driverStale: driver?.stale ?? false,
      driverAssumed: driver?.assumed ?? false,
      tileProvider: ref.watch(orderMapTileProviderProvider),
    );
  }
}

/// One line under the map saying what it's showing right now.
class _MapCaption extends StatelessWidget {
  const _MapCaption({required this.order});

  final OrderTracking order;

  @override
  Widget build(BuildContext context) {
    final String? text;
    final driver = order.driver;
    if (order.status == OrderStatus.outForDelivery) {
      if (driver == null) {
        text = 'السائق غادر المتجر — ننتظر مشاركة موقعه المباشر.';
      } else if (DateTime.now().difference(driver.updatedAt) > _driverStaleAfter) {
        text = 'آخر موقع معروف للسائق ${DateFormat('HH:mm').format(driver.updatedAt)} — قد لا يكون محدّثاً.';
      } else {
        text = 'السائق في الطريق إليك • آخر تحديث للموقع ${DateFormat('HH:mm').format(driver.updatedAt)}';
      }
    } else if (!order.hasDeliveryPin) {
      text = 'لم تحدد موقع التوصيل على الخريطة عند الطلب، لذا يظهر موقع المتجر فقط.';
    } else {
      text = null;
    }
    if (text == null) return const SizedBox(height: 4);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Icon(
            order.status == OrderStatus.outForDelivery ? Icons.delivery_dining : Icons.info_outline,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              key: const ValueKey('map-caption'),
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.order});

  final OrderTracking order;

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final cancelled = status == OrderStatus.cancelled;
    final delivered = status == OrderStatus.delivered;
    final background = cancelled
        ? AppColors.accent
        : delivered
            ? AppColors.success
            : AppColors.primary;
    final icon = cancelled
        ? Icons.cancel_outlined
        : delivered
            ? Icons.check_circle_outline
            : status == OrderStatus.outForDelivery
                ? Icons.delivery_dining
                : status == OrderStatus.preparing
                    ? Icons.shopping_basket_outlined
                    : Icons.receipt_long_outlined;

    final expected = order.expectedBy;
    final showEta = status.isActive && expected != null;
    final overdue = showEta && DateTime.now().isAfter(expected);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(18)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  status.headlineAr,
                  key: const ValueKey('order-headline'),
                  style: AppTextStyles.h2.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(status.detailAr, style: AppTextStyles.body.copyWith(color: Colors.white.withValues(alpha: 0.9))),
          if (showEta) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      overdue
                          ? 'قد يتأخر قليلاً عن الوقت المتوقع (${DateFormat('HH:mm').format(expected)})'
                          : 'الوصول المتوقع حوالي ${DateFormat('HH:mm').format(expected)}',
                      key: const ValueKey('order-eta'),
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (status.isActive) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  'يتحدّث تلقائياً',
                  style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
                const SizedBox(width: 12),
              ],
              Text(
                'آخر تحديث ${DateFormat('HH:mm').format(order.updatedAt)}',
                style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CancelledNotice extends StatelessWidget {
  const _CancelledNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        'تم إلغاء هذا الطلب ولن يتم توصيله. يمكنك تقديم طلب جديد في أي وقت.',
        style: AppTextStyles.body.copyWith(color: AppColors.accentDark),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.order});

  final OrderTracking order;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final line in order.items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 34,
                  child: Text('${line.quantity}×', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
                ),
                Expanded(child: Text(line.name, style: AppTextStyles.body)),
                const SizedBox(width: 8),
                Text(CurrencyFormatter.jod(line.lineTotal), style: AppTextStyles.body),
              ],
            ),
          ),
        const Divider(color: AppColors.border, height: 24),
        _MoneyRow(label: 'المجموع الفرعي', value: CurrencyFormatter.jod(order.subtotal)),
        const SizedBox(height: 6),
        _MoneyRow(
          label: order.zoneName == null ? 'رسوم التوصيل' : 'رسوم التوصيل (${order.zoneName})',
          value: order.deliveryFee == 0 ? 'مجاني' : CurrencyFormatter.jod(order.deliveryFee),
        ),
        const Divider(color: AppColors.border, height: 24),
        _MoneyRow(label: 'الإجمالي', value: CurrencyFormatter.jod(order.total), emphasize: true),
      ],
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value, this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? AppTextStyles.h3.copyWith(color: AppColors.primary)
        : AppTextStyles.body.copyWith(color: AppColors.textSecondary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                Text(value, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.detail, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(detail, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (actionLabel != null) ElevatedButton(onPressed: onAction, child: Text(actionLabel!)),
            if (actionLabel != null) const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => context.go('/home'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    );
  }
}
