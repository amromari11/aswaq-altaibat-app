import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isGuest = ref.watch(isGuestProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.person_outline, color: AppColors.primary, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              user != null ? (user.phone ?? 'مستخدم مسجل') : 'زائر',
              style: AppTextStyles.h2,
            ),
            const SizedBox(height: 4),
            Text(
              isGuest && user == null
                  ? 'سجل الدخول للوصول إلى نقاط الولاء وتتبع الطلبات'
                  : 'عضو في أسواق الطيبات',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            if (user == null)
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: const Text('تسجيل الدخول'),
              )
            else
              OutlinedButton(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  ref.read(isGuestProvider.notifier).state = false;
                  if (context.mounted) context.go('/login');
                },
                child: const Text('تسجيل الخروج'),
              ),
          ],
        ),
      ),
    );
  }
}
