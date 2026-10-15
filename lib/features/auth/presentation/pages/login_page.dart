import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final rawPhone = _phoneController.text.trim();
    if (rawPhone.isEmpty) {
      setState(() => _errorMessage = 'الرجاء إدخال رقم الهاتف.');
      return;
    }

    // Jordanian mobile numbers: accept "07XXXXXXXX" or "+9627XXXXXXXX" and
    // normalize to E.164, which Supabase phone auth requires.
    final normalized = rawPhone.startsWith('+')
        ? rawPhone
        : '+962${rawPhone.startsWith('0') ? rawPhone.substring(1) : rawPhone}';

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).sendOtp(normalized);
      if (!mounted) return;
      context.push('/verify-otp', extra: normalized);
    } catch (error) {
      setState(() => _errorMessage = 'تعذر إرسال الرمز. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _browseAsGuest() {
    ref.read(isGuestProvider.notifier).state = true;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.storefront, color: AppColors.primary, size: 36),
              ),
              const SizedBox(height: 24),
              Text('تسجيل الدخول', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              Text(
                'أدخل رقم هاتفك لإرسال رمز التحقق',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  hintText: '07XX XXX XXX',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('+962', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                  prefixIconConstraints: BoxConstraints(minWidth: 0),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _sendOtp,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('إرسال الرمز'),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _browseAsGuest,
                  child: Text(
                    'التصفح كزائر',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
