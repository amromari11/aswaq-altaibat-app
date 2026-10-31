import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../cart/domain/entities/fulfillment.dart';
import '../../../cart/domain/services/slot_planner.dart';
import '../../domain/entities/order_status.dart';
import '../../domain/entities/order_tracking.dart';
import '../providers/order_providers.dart';

/// Order history: this device's orders (and a signed-in customer's account
/// orders), active ones first. Tap any order to open its live tracking.
class MyOrdersPage extends ConsumerStatefulWidget {
  const MyOrdersPage({super.key});

  @override
  ConsumerState<MyOrdersPage> createState() => _MyOrdersPageState();
}

class _MyOrdersPageState extends ConsumerState<MyOrdersPage> {
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    // Statuses move while the list is open (the tab stays alive in the nav
    // shell), so keep it reasonably fresh without the customer pulling down.
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) ref.invalidate(ordersListProvider);
    });
  }

  @override
  void dispose() {
    _refresh?.cancel();
    super.dispose();
  }

  Future<void> _open(OrderSummary order) async {
    await context.push('/order/${order.ref.id}?t=${order.ref.token}');
    // Back from tracking: the status may have moved while we were away.
    if (mounted) ref.invalidate(ordersListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(ordersListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(ordersListProvider);
          await ref.read(ordersListProvider.future).catchError((_) => <OrderSummary>[]);
        },
        child: orders.when(
          // A refresh keeps the old list on screen instead of flashing a spinner.
          skipLoadingOnRefresh: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _Scrollable(
            child: _Empty(
              icon: Icons.wifi_off,
              title: 'تعذر تحميل طلباتك',
              detail: 'تحقق من الاتصال واسحب للأسفل لإعادة المحاولة.',
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(ordersListProvider),
            ),
          ),
          data: (list) {
            if (list.isEmpty) {
              return _Scrollable(
                child: _Empty(
                  icon: Icons.receipt_long_outlined,
                  title: 'لا توجد طلبات بعد',
                  detail: 'ستظهر طلباتك هنا ويمكنك تتبعها بعد إتمام أول عملية شراء.',
                  actionLabel: 'ابدأ التسوق',
                  onAction: () => context.go('/home'),
                ),
              );
            }
            final active = list.where((o) => o.status.isActive).toList();
            final past = list.where((o) => !o.status.isActive).toList();
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (active.isNotEmpty) ...[
                  Text('طلبات نشطة', style: AppTextStyles.h3),
                  const SizedBox(height: 10),
                  for (final order in active) _OrderCard(order: order, onTap: () => _open(order)),
                ],
                if (past.isNotEmpty) ...[
                  if (active.isNotEmpty) const SizedBox(height: 12),
                  Text('الطلبات السابقة', style: AppTextStyles.h3),
                  const SizedBox(height: 10),
                  for (final order in past) _OrderCard(order: order, onTap: () => _open(order)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final OrderSummary order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    final color = status == OrderStatus.cancelled
        ? AppColors.accent
        : status == OrderStatus.delivered
            ? AppColors.success
            : AppColors.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: status.isActive ? color : AppColors.border,
                  width: status.isActive ? 1.5 : 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(order.ref.displayCode, style: AppTextStyles.h3),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status.labelFor(order.orderType),
                        style: AppTextStyles.caption
                            .copyWith(color: color, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${DateFormat('yyyy-MM-dd HH:mm').format(order.createdAt)} • ${order.itemCount} منتجات'
                  '${order.orderType == OrderType.pickup ? ' • استلام من الفرع' : (order.zoneName == null ? '' : ' • ${order.zoneName}')}'
                  '${order.scheduledTime == null || !status.isActive ? '' : ' • موعد ${SlotPlanner.moment(order.scheduledTime!, DateTime.now())}'}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(CurrencyFormatter.jod(order.total),
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
                    const Spacer(),
                    if (status.isActive) ...[
                      Text('تتبع الطلب',
                          style: AppTextStyles.caption
                              .copyWith(color: color, fontWeight: FontWeight.w700)),
                      Icon(Icons.chevron_left, color: color, size: 20),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets an empty/error state still be pulled to refresh.
class _Scrollable extends StatelessWidget {
  const _Scrollable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child)),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(
      {required this.icon,
      required this.title,
      required this.detail,
      required this.actionLabel,
      required this.onAction});

  final IconData icon;
  final String title;
  final String detail;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(title, style: AppTextStyles.h3),
          const SizedBox(height: 6),
          Text(detail,
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
