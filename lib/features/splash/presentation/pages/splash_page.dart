import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/brand_assets.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Branded splash shown while the app decides where to route (signed in /
/// guest / needs login).
///
/// The animation is streamed from LottieFiles' public asset CDN rather than
/// bundled — see BrandAssets.fastDeliveryLottieUrl for how it was verified.
/// If LottieFiles ever moves/removes this asset, `errorBuilder` below falls
/// back to a static brand mark instead of a blank screen.
const _splashDuration = Duration(milliseconds: 2500);

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
      // supabase_flutter restores a persisted session (if any) by the time
      // Supabase.initialize() in main() returns, well before this timer
      // fires — so a returning signed-in user goes straight to /home
      // instead of being forced through /login every cold start.
      context.go(_isSignedIn() ? '/home' : '/login');
    });
  }

  bool _isSignedIn() {
    try {
      return Supabase.instance.client.auth.currentUser != null;
    } catch (_) {
      // Supabase.instance throws if .initialize() was never called for this
      // process — only happens in the widget-test harness, which
      // deliberately skips it to avoid a network dependency.
      return false;
    }
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
