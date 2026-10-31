import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/external_launcher.dart';
import '../../../../core/utils/jordan_phone.dart';
import '../../../cart/domain/services/slot_planner.dart';
import '../../../cart/presentation/providers/fulfillment_providers.dart';
import '../../domain/entities/order_ref.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/order_tracking.dart';
import '../../domain/services/trip_math.dart';
import '../providers/order_providers.dart';
import '../widgets/driver_card.dart';
import '../widgets/order_map.dart';
import '../widgets/order_progress_bar.dart';
import '../widgets/order_stepper.dart';

/// Live tracking for one order. Opened right after checkout and from the
/// orders list; works for guests (the [OrderRef] token is the key) and keeps
/// itself current via Realtime (see [orderTrackingProvider]).
///
/// Layout: the map fills the top of the screen with a floating back button, the
/// order number and an arrival card on it; a rounded sheet slides over its
/// lower edge with the arrival time, progress, driver and order details.
class OrderTrackingPage extends ConsumerWidget {
  const OrderTrackingPage({super.key, required this.orderRef});

  final OrderRef orderRef;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracking = ref.watch(orderTrackingProvider(orderRef));
    final order = tracking.valueOrNull;
    // With a map the page has no app bar: its controls float over the map.
    final floating = order != null && order.status != OrderStatus.cancelled;

    return Scaffold(
      appBar: floating
          ? null
          : AppBar(
              title: Text('تتبع الطلب ${orderRef.displayCode}'),
              // After checkout this screen replaces the cart/checkout stack, so
              // there may be nothing to pop: offer Home instead of a dead back arrow.
              leading: context.canPop()
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
            : _Clock(
                builder: (context, now) => _Content(order: order, code: orderRef.displayCode, now: now),
              ),
      ),
    );
  }
}

/// Rebuilds its child every half minute so "arriving in N minutes" stays true
/// without waiting for the order itself to change.
class _Clock extends StatefulWidget {
  const _Clock({required this.builder});

  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

/// A driver position older than this is flagged as possibly out of date.
const _driverStaleAfter = Duration(minutes: 3);

class _Content extends ConsumerWidget {
  const _Content({required this.order, required this.code, required this.now});

  final OrderTracking order;
  final String code;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = order.status;
    final showMap = status != OrderStatus.cancelled;
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    final showDriver = status == OrderStatus.outForDelivery && !order.isPickup;

    final body = <Widget>[
      _ArrivalHeader(order: order, now: now),
      const SizedBox(height: 16),
      if (status == OrderStatus.cancelled)
        const _CancelledNotice()
      else
        OrderProgressBar(status: status, orderType: order.orderType),
      const SizedBox(height: 12),
      _LiveRow(order: order),
      if (showMap) _MapCaption(order: order),
      if (order.scheduledTime != null && status.isActive) ...[
        const SizedBox(height: 12),
        _SlotChip(order: order, now: now),
      ],
      if (showDriver) ...[
        const SizedBox(height: 16),
        DriverCard(
          name: order.driverInfo?.name,
          driverPhone: order.driverInfo?.phone,
          storePhone: settings?.branchPhone,
        ),
      ],
      const SizedBox(height: 16),
      if (status != OrderStatus.cancelled) ...[
        _Card(
          title: 'مراحل الطلب',
          child: OrderStepper(status: status, orderType: order.orderType),
        ),
        const SizedBox(height: 16),
      ],
      _Card(
        title: order.isPickup ? 'تفاصيل الاستلام' : 'تفاصيل التوصيل',
        child: Column(
          children: [
            if (order.isPickup)
              const _BranchRow()
            else ...[
              _DetailRow(icon: Icons.location_on_outlined, label: 'العنوان', value: order.deliveryAddress),
              if (order.zoneName != null)
                _DetailRow(icon: Icons.map_outlined, label: 'منطقة التوصيل', value: order.zoneName!),
            ],
            if (order.scheduledTime != null)
              _DetailRow(
                icon: Icons.event_outlined,
                label: order.isPickup ? 'موعد الاستلام' : 'موعد التوصيل',
                value: SlotPlanner.moment(order.scheduledTime!, now),
              ),
            if (!order.isPickup && order.scheduledTime == null && order.etaMinutes != null)
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
      Builder(
        builder: (context) => ElevatedButton.icon(
          onPressed: () => context.go('/home'),
          icon: const Icon(Icons.home_outlined),
          label: const Text('العودة للرئيسية'),
        ),
      ),
      const SizedBox(height: 10),
      Builder(
        builder: (context) => OutlinedButton.icon(
          onPressed: () => context.go('/orders'),
          icon: const Icon(Icons.receipt_long_outlined),
          label: const Text('طلباتي'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            minimumSize: const Size.fromHeight(48),
          ),
        ),
      ),
    ];

    // Cancelled: no map, an ordinary page (the app bar is the parent's).
    if (!showMap) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), children: body);
    }

    final size = MediaQuery.sizeOf(context);
    final topPad = MediaQuery.paddingOf(context).top;
    final mapHeight = (size.height * 0.5).clamp(320.0, 460.0);
    const overlap = 28.0;

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: mapHeight,
          // The cards on top and the sheet below cover part of the map; the pins are framed clear of them.
          child: _TrackingMap(order: order, topInset: topPad + _MapEtaCard.bottomEdge, bottomInset: overlap + 8),
        ),
        Positioned(
          top: topPad + 8,
          left: 12,
          right: 12,
          child: _TopBar(code: code, callPhone: settings?.branchPhone),
        ),
        Positioned(
          top: topPad + 66,
          left: 12,
          right: 12,
          child: _MapEtaCard(order: order, now: now),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: mapHeight - overlap,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.canvas,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, -4)),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
                ),
                Expanded(
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 32), children: body),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Floating row on the map: back (or home), the order number, call the shop.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.code, this.callPhone});

  final String code;

  /// The shop's number as typed in the store settings; no call button without it.
  final String? callPhone;

  @override
  Widget build(BuildContext context) {
    final canGoBack = context.canPop();
    final phone = callPhone == null ? null : JordanPhone.normalize(callPhone!);
    return Row(
      children: [
        _MapButton(
          icon: canGoBack ? Icons.arrow_back : Icons.home_outlined,
          tooltip: canGoBack ? 'رجوع' : 'الرئيسية',
          onTap: () => canGoBack ? context.pop() : context.go('/home'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.18), blurRadius: 10)],
              ),
              child: Text(
                'تتبع الطلب $code',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (phone != null)
          Consumer(
            builder: (context, ref, _) => _MapButton(
              icon: Icons.call_outlined,
              tooltip: 'اتصل بالمتجر',
              onTap: () => ref.read(externalLauncherProvider)(Uri(scheme: 'tel', path: phone)),
            ),
          )
        else
          const SizedBox(width: 44),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.tooltip, required this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

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
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.18), blurRadius: 10)],
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }
}

/// Small card on the map: what is happening and how far the driver has to go.
class _MapEtaCard extends StatelessWidget {
  const _MapEtaCard({required this.order, required this.now});

  final OrderTracking order;
  final DateTime now;

  static const progressKey = ValueKey('map-eta-progress');
  static const distanceKey = ValueKey('map-eta-distance');

  /// How far down the map the card reaches (it starts 66 below the top, and is about 84 tall):
  /// the pins are framed below this so none hides behind it.
  static const bottomEdge = 150.0;

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final minutes = minutesLeft(order, now);
    final onTheWay = status == OrderStatus.outForDelivery && !order.isPickup;
    final driver = order.driver;
    final trip = onTheWay
        ? tripProgress(
            store: const LatLng(AppConfig.storeLatitude, AppConfig.storeLongitude),
            home: order.hasDeliveryPin ? LatLng(order.deliveryLat!, order.deliveryLng!) : null,
            driver: driver == null ? null : LatLng(driver.latitude, driver.longitude),
          )
        : null;

    final String title;
    if (status.isActive && minutes != null) {
      title = minutes == 0 ? 'يصل خلال لحظات' : 'الوصول خلال ${minutesWords(minutes)}';
    } else if (status.isActive && order.scheduledTime != null) {
      title = 'موعدك ${SlotPlanner.moment(order.scheduledTime!, now)}';
    } else {
      // Nothing to count down: just the stage (the sheet below has the full sentence).
      title = status.labelFor(order.orderType);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.primaryDark.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                child: Icon(_iconFor(status, order), color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != status.labelFor(order.orderType))
                      Text(
                        status.labelFor(order.orderType),
                        style: AppTextStyles.caption.copyWith(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    Text(
                      title,
                      key: const ValueKey('map-eta-title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
              if (trip != null) ...[
                const SizedBox(width: 8),
                Text(
                  'يبعد ${distanceLabel(trip.remainingKm)}',
                  key: distanceKey,
                  style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
              ],
            ],
          ),
          if (trip != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.storefront, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      key: progressKey,
                      value: trip.fraction,
                      minHeight: 5,
                      backgroundColor: AppColors.border,
                      color: AppColors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.home, size: 16, color: AppColors.accent),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static IconData _iconFor(OrderStatus status, OrderTracking order) {
    if (status == OrderStatus.delivered) return Icons.check_circle_outline;
    if (status == OrderStatus.outForDelivery) return order.isPickup ? Icons.storefront : Icons.delivery_dining;
    if (status == OrderStatus.preparing) return Icons.shopping_basket_outlined;
    return Icons.receipt_long_outlined;
  }
}

/// Top of the sheet: "arriving in N minutes" with an on-time chip, then the
/// status headline (and, for an order with an estimate, the time it is due).
class _ArrivalHeader extends StatelessWidget {
  const _ArrivalHeader({required this.order, required this.now});

  final OrderTracking order;
  final DateTime now;

  static const minutesKey = ValueKey('order-minutes-left');

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final expected = order.expectedBy;
    final showEta = status.isActive && expected != null;
    final overdue = showEta && now.isAfter(expected);
    final minutes = minutesLeft(order, now);
    final cancelled = status == OrderStatus.cancelled;
    final delivered = status == OrderStatus.delivered;
    final accent = cancelled ? AppColors.accent : (delivered ? AppColors.success : AppColors.primary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showEta) ...[
          Row(
            children: [
              Expanded(
                child: Text('الوصول خلال', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
              ),
              _Chip(
                text: overdue ? 'تأخير بسيط' : 'في الموعد',
                color: overdue ? AppColors.accent : AppColors.success,
              ),
            ],
          ),
          Text(
            minutes == null ? '' : minutesWords(minutes),
            key: minutesKey,
            style: AppTextStyles.h1.copyWith(fontSize: 30, color: AppColors.primaryDark),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(_icon(status), color: accent, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                status.headlineFor(order.orderType),
                key: const ValueKey('order-headline'),
                style: AppTextStyles.h3.copyWith(fontWeight: FontWeight.w800, color: accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(status.detailFor(order.orderType), style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        if (showEta) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  overdue
                      ? 'قد يتأخر قليلاً عن الوقت المتوقع (${DateFormat('HH:mm').format(expected)})'
                      : 'الوصول المتوقع حوالي ${DateFormat('HH:mm').format(expected)}',
                  key: const ValueKey('order-eta'),
                  style: AppTextStyles.bodyMedium.copyWith(color: overdue ? AppColors.accent : AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  static IconData _icon(OrderStatus status) {
    switch (status) {
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
      case OrderStatus.delivered:
        return Icons.check_circle_outline;
      case OrderStatus.outForDelivery:
        return Icons.delivery_dining;
      case OrderStatus.preparing:
        return Icons.shopping_basket_outlined;
      default:
        return Icons.receipt_long_outlined;
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w800)),
    );
  }
}

/// "يتحدّث تلقائياً" while there is more to come, and when it last changed.
class _LiveRow extends StatelessWidget {
  const _LiveRow({required this.order});

  final OrderTracking order;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (order.status.isActive) ...[
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text('يتحدّث تلقائياً', style: AppTextStyles.caption),
          const SizedBox(width: 12),
        ],
        Text('آخر تحديث ${DateFormat('HH:mm').format(order.updatedAt)}', style: AppTextStyles.caption),
      ],
    );
  }
}

/// The chosen delivery / pickup slot of a scheduled order.
class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.order, required this.now});

  final OrderTracking order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_outlined, color: AppColors.primary, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${order.isPickup ? 'موعد الاستلام' : 'موعد التوصيل'}: ${SlotPlanner.moment(order.scheduledTime!, now)}',
              key: const ValueKey('order-slot'),
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the driver marker should show for [order]: their real position when
/// they've shared one, otherwise — once the order has left the store — the
/// store itself (greyed, so it isn't mistaken for a live fix).
({LatLng point, bool stale, bool assumed})? _driverOnMap(OrderTracking order) {
  if (order.status != OrderStatus.outForDelivery || order.isPickup) return null;
  final driver = order.driver;
  if (driver == null) {
    return (
      point: const LatLng(AppConfig.storeLatitude, AppConfig.storeLongitude),
      stale: true,
      assumed: true
    );
  }
  final old = DateTime.now().difference(driver.updatedAt) > _driverStaleAfter;
  return (point: LatLng(driver.latitude, driver.longitude), stale: old, assumed: false);
}

class _TrackingMap extends ConsumerWidget {
  const _TrackingMap({required this.order, this.topInset = 0, this.bottomInset = 0});

  final OrderTracking order;
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driver = _driverOnMap(order);
    return OrderMap(
      store: const LatLng(AppConfig.storeLatitude, AppConfig.storeLongitude),
      home: !order.isPickup && order.hasDeliveryPin
          ? LatLng(order.deliveryLat!, order.deliveryLng!)
          : null,
      driver: driver?.point,
      driverStale: driver?.stale ?? false,
      driverAssumed: driver?.assumed ?? false,
      tileProvider: ref.watch(orderMapTileProviderProvider),
      borderRadius: 0,
      topInset: topInset,
      bottomInset: bottomInset,
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
    if (order.isPickup) {
      text = order.status == OrderStatus.outForDelivery
          ? 'طلبك جاهز — استلمه من الفرع الظاهر على الخريطة.'
          : 'موقع الفرع الذي ستستلم منه طلبك.';
    } else if (order.status == OrderStatus.outForDelivery) {
      if (driver == null) {
        text = 'السائق غادر المتجر — ننتظر مشاركة موقعه المباشر.';
      } else if (DateTime.now().difference(driver.updatedAt) > _driverStaleAfter) {
        text =
            'آخر موقع معروف للسائق ${DateFormat('HH:mm').format(driver.updatedAt)} — قد لا يكون محدّثاً.';
      } else {
        text =
            'السائق في الطريق إليك • آخر تحديث للموقع ${DateFormat('HH:mm').format(driver.updatedAt)}';
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
            order.isPickup
                ? Icons.storefront
                : (order.status == OrderStatus.outForDelivery
                    ? Icons.delivery_dining
                    : Icons.info_outline),
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
                  child: Text('${line.quantity}×',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
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
          label: order.isPickup
              ? 'رسوم التوصيل (استلام من الفرع)'
              : (order.zoneName == null ? 'رسوم التوصيل' : 'رسوم التوصيل (${order.zoneName})'),
          value: order.isPickup
              ? CurrencyFormatter.jod(0)
              : (order.deliveryFee == 0 ? 'مجاني' : CurrencyFormatter.jod(order.deliveryFee)),
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
  const _Message(
      {required this.icon,
      required this.title,
      required this.detail,
      this.actionLabel,
      this.onAction});

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
            Text(detail,
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
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

/// The pickup branch (from the store settings; the store name if they can't be loaded).
class _BranchRow extends ConsumerWidget {
  const _BranchRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(storeSettingsProvider).valueOrNull;
    return Column(
      children: [
        _DetailRow(
            icon: Icons.storefront_outlined,
            label: 'الفرع',
            value: settings?.branchName ?? AppConfig.storeName),
        if (settings != null) ...[
          _DetailRow(
              icon: Icons.location_on_outlined, label: 'العنوان', value: settings.branchAddress),
          _DetailRow(icon: Icons.access_time, label: 'ساعات العمل', value: settings.hoursLabel),
        ],
      ],
    );
  }
}
