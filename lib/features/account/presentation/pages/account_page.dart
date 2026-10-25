import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/supabase/supabase_providers.dart';
import '../../../../core/utils/jordan_phone.dart';
import '../../data/repositories/profile_repository.dart';
import '../providers/profile_providers.dart';
import '../widgets/phone_entry_fields.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final meta = user?.userMetadata ?? const {};
    final displayName = (meta['full_name'] ?? meta['name']) as String?;
    final phone = ref.watch(profilePhoneProvider).valueOrNull;

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
              user != null ? (displayName ?? user.email ?? 'مستخدم مسجل') : 'زائر',
              style: AppTextStyles.h2,
            ),
            if (user?.email != null && displayName != null)
              Text(user!.email!, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text(
              user == null
                  ? 'سجل الدخول للوصول إلى نقاط الولاء وتتبع الطلبات'
                  : 'عضو في أسواق الطيبات',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
              title: const Text('عناوين التوصيل'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => context.push('/addresses'),
            ),
            if (user != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined, color: AppColors.primary),
                title: const Text('رقم الهاتف'),
                subtitle: Text(
                  phone == null ? 'لم يُضف بعد' : JordanPhone.toLocal(phone),
                  textDirection: phone == null ? null : TextDirection.ltr,
                  textAlign: TextAlign.start,
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const _PhoneSheet(),
                ),
              ),
            const SizedBox(height: 8),
            if (user == null)
              ElevatedButton(
                onPressed: () => context.push('/login'),
                child: const Text('تسجيل الدخول'),
              )
            else
              OutlinedButton(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  if (context.mounted) context.go('/home');
                },
                child: const Text('تسجيل الخروج'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Set/change the profile phone — double entry, no OTP.
class _PhoneSheet extends ConsumerStatefulWidget {
  const _PhoneSheet();

  @override
  ConsumerState<_PhoneSheet> createState() => _PhoneSheetState();
}

class _PhoneSheetState extends ConsumerState<_PhoneSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await savePhone(ref, JordanPhone.normalize(_phone.text)!);
      if (mounted) Navigator.of(context).pop();
    } on PhoneTakenException {
      setState(() => _error = 'رقم الهاتف هذا مسجل لحساب آخر.');
    } catch (_) {
      setState(() => _error = 'تعذر حفظ الرقم. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('رقم الهاتف', style: AppTextStyles.h3),
            const SizedBox(height: 4),
            Text(
              'أدخل الرقم مرتين للتأكد من صحته — سيتصل بك السائق عليه.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            PhoneEntryFields(phoneController: _phone, confirmController: _confirm),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
