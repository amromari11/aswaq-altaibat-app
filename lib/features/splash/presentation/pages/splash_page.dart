import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../../../core/constants/brand_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Branded splash: the delivery-scooter animation and the store slogan,
/// then straight into the app. Everyone lands on /home — browsing needs no
/// account; sign-in is only asked for when placing an order (checkout).
///
/// The animation is streamed from LottieFiles' public asset CDN rather than
/// bundled — see BrandAssets.fastDeliveryLottieUrl for how it was verified.
/// If LottieFiles ever moves/removes this asset, `errorBuilder` below falls
/// back to a static brand mark instead of a blank screen.
const _splashDuration = Duration(milliseconds: 2500);

const slogan = 'أسواق الطيبات: جودة تختارها، وسرعة تعتمد عليها.';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  late final Animation<double> _scale = Tween<double>(begin: 0.92, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    Timer(_splashDuration, () {
      if (!mounted) return;
      context.go('/home');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Lottie.network(
                    BrandAssets.fastDeliveryLottieUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.local_shipping_rounded,
                      color: AppColors.primary,
                      size: 96,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'أسواق الطيبات',
                  style: AppTextStyles.h1.copyWith(
                    color: AppColors.primary,
                    fontSize: 28,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  width: 48,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  // Break after the colon so it reads as brand + promise
                  // rather than wrapping one word onto its own line.
                  child: Text(
                    slogan.replaceFirst(': ', ':\n'),
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
