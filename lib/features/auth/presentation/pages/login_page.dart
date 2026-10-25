import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/brand_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  bool _isSubmittingGoogle = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSubmittingGoogle = true;
      _errorMessage = null;
    });

    try {
      // On web this redirects the whole page away and back; on mobile the
      // OAuth callback completes the session and currentUserProvider picks
      // it up via onAuthStateChange. Either way, no manual navigation here —
      // the app-level listener in main.dart does it once sign-in actually
      // completes. Requires Google configured under Authentication →
      // Providers in Supabase, plus the redirect URL registered on each
      // platform — see AuthRepository.signInWithGoogle.
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (error) {
      setState(() => _errorMessage = 'تعذر تسجيل الدخول عبر Google. حاول مرة أخرى.');
    } finally {
      if (mounted) setState(() => _isSubmittingGoogle = false);
    }
  }

  /// Back to wherever the login was opened from (checkout or the account
  /// tab) — browsing never requires an account.
  void _continueShopping() {
    ref.read(pendingRedirectProvider.notifier).state = null;
    ref.read(resumeCheckoutAfterSignInProvider.notifier).state = false;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  /// Debug-only (see the `kDebugMode` gate in build()): skips Supabase Auth
  /// entirely — just flips [isMockSignedInProvider] and jumps straight to
  /// Checkout, so the checkout/location-picker UI (cart summary, address
  /// entry, phone entry, the OSM map) can be reached and tested instantly
  /// without a configured Google provider.
  ///
  /// This is **not** a real sign-in: `currentUserProvider` (Supabase's
  /// actual `auth.uid()`) stays null, so RLS still refuses to let "تأكيد
  /// الطلب" actually place an order — that part of the flow still needs a
  /// real session. See the caption under the button below.
  void _mockSignInAndGoToCheckout() {
    ref.read(isMockSignedInProvider.notifier).state = true;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/checkout');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Scrollable: the hero animation + full form + Google button no
      // longer reliably fits a short device (e.g. iPhone SE) without
      // scrolling, so this avoids a bottom overflow there instead of
      // trying to cram everything into one fixed screen.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 190,
                child: Lottie.network(
                  BrandAssets.fastDeliveryLottieUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.local_shipping_rounded,
                    color: AppColors.primary,
                    size: 72,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'أسواق الطيبات',
                textAlign: TextAlign.center,
                style: AppTextStyles.h1.copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 28),
              Text('تسجيل الدخول', style: AppTextStyles.h2),
              const SizedBox(height: 6),
              Text(
                ref.read(pendingRedirectProvider) == '/checkout'
                    ? 'خطوة أخيرة: سجّل الدخول بحساب Google لتأكيد طلبك ومتابعته.'
                    : 'سجّل الدخول بحساب Google لإتمام طلباتك ومتابعتها.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _isSubmittingGoogle ? null : _signInWithGoogle,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSubmittingGoogle
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.string(
                            BrandAssets.googleLogoSvg,
                            width: 20,
                            height: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'تسجيل الدخول عبر Google',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(_errorMessage!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 20),
              TextButton(
                onPressed: _continueShopping,
                child: Text(
                  'متابعة التسوق',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryDark),
                ),
              ),
              // Dev-only: kDebugMode is a compile-time constant, so this
              // entire block (and the button it shows) is stripped out of
              // release/profile builds — it can never reach a real user.
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.construction, size: 16, color: Colors.amber.shade800),
                          const SizedBox(width: 6),
                          Text(
                            'وضع التطوير فقط',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.amber.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: _mockSignInAndGoToCheckout,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.amber.shade900,
                          side: BorderSide(color: Colors.amber.shade400),
                        ),
                        child: const Text('تسجيل دخول تجريبي (لاختبار الطلب)'),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'دخول وهمي محلي فقط — ينقلك لشاشة إتمام الطلب مباشرة، لكن "تأكيد الطلب" يبقى يطلب تسجيل دخول حقيقي لأن Supabase لا يرى جلسة فعلية.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(color: Colors.amber.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
