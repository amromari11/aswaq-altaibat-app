import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/driver_repository.dart';
import '../providers/driver_providers.dart';
import '../widgets/driver_order_card.dart';

/// Driver mode: the availability switch the shop sees live, and the orders
/// assigned to this driver with their actions. Drivers land here straight
/// after sign-in (see main.dart / the splash screen).
class DriverDashboardPage extends ConsumerWidget {
  const DriverDashboardPage({super.key});

  static const availabilityKey = ValueKey('driver-availability');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(driverProfileProvider);

    Widget body;
    if (user == null) {
      body = _Message(
        icon: Icons.lock_outline,
        text: 'سجّل الدخول بحساب السائق للمتابعة.',
        action: FilledButton(onPressed: () => context.push('/login'), child: const Text('تسجيل الدخول')),
      );
    } else if (profile.isLoading && !profile.hasValue) {
      body = const Center(child: CircularProgressIndicator());
    } else if (!(profile.valueOrNull?.isDriver ?? false)) {
      body = _Message(
        icon: Icons.no_accounts_outlined,
        text: 'هذا الحساب غير مسجّل كسائق.\nتواصل مع إدارة المتجر لتفعيل وضع السائق.',
        action: OutlinedButton(onPressed: () => context.go('/home'), child: const Text('العودة للمتجر')),
      );
    } else {
      body = const _Dashboard();
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('وضع السائق'),
        actions: [
          if (user != null)
            IconButton(
              tooltip: 'تسجيل الخروج',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) context.go('/home');
              },
            ),
        ],
      ),
      body: body,
    );
  }
}

class _Dashboard extends ConsumerWidget {
  const _Dashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(driverOrdersProvider);
    final name = ref.watch(driverProfileProvider).valueOrNull?.fullName;

    return RefreshIndicator(
      onRefresh: () => ref.read(driverOrdersProvider.notifier).refresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _AvailabilityCard(name: name),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('طلباتي', style: AppTextStyles.h2),
              const SizedBox(width: 8),
              if (orders.valueOrNull?.isNotEmpty ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '${orders.value!.length}',
                    style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...orders.when(
            loading: () => const [Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))],
            error: (e, _) => [
              _Message(
                icon: Icons.wifi_off_outlined,
                text: e is DriverActionException ? e.messageAr : 'تعذّر تحميل الطلبات. اسحب للأسفل للمحاولة مجدداً.',
              ),
            ],
            data: (list) => list.isEmpty
                ? const [
                    _Message(
                      icon: Icons.inbox_outlined,
                      text: 'لا توجد طلبات مسندة إليك حالياً.\nستظهر هنا فور إسنادها من المتجر.',
                    ),
                  ]
                : [
                    for (final order in list) ...[
                      DriverOrderCard(key: ValueKey(order.id), order: order),
                      const SizedBox(height: 12),
                    ],
                  ],
          ),
        ],
      ),
    );
  }
}

class _AvailabilityCard extends ConsumerWidget {
  const _AvailabilityCard({this.name});

  final String? name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(driverAvailabilityProvider);
    final on = availability.valueOrNull ?? false;
    final loading = availability.isLoading;

    Future<void> toggle(bool value) async {
      try {
        await ref.read(driverAvailabilityProvider.notifier).set(value);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e is DriverActionException ? e.messageAr : 'تعذّر تحديث حالتك، حاول مرة أخرى.'),
        ));
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
      decoration: BoxDecoration(
        gradient: on
            ? const LinearGradient(colors: [Color(0xFF15803D), AppColors.success])
            : AppColors.headerGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: (on ? AppColors.success : AppColors.primary).withValues(alpha: 0.28),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
            child: Icon(on ? Icons.delivery_dining : Icons.bedtime_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (name != null && name!.trim().isNotEmpty)
                  Text('أهلاً ${name!.trim()}', style: AppTextStyles.caption.copyWith(color: Colors.white70)),
                Text('متاح للتوصيل', style: AppTextStyles.h3.copyWith(color: Colors.white)),
                Text(
                  on ? 'يراك المتجر متاحاً لاستلام طلبات جديدة' : 'لن تُسند إليك طلبات جديدة الآن',
                  style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          Switch(
            key: DriverDashboardPage.availabilityKey,
            value: on,
            onChanged: loading ? null : toggle,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.45),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
