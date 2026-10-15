import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Branded splash shown while the app decides where to route (signed in /
/// guest / needs login).
///
/// No Lottie asset is bundled yet — `assets/lottie/splash.json` doesn't
/// exist in this repo, and referencing a missing asset crashes the app, so
/// this uses a plain scale+fade animation instead. The `lottie` package is
/// already a dependency: once a real delivery/grocery animation file is
/// dropped into `assets/lottie/splash.json`, replace the `ScaleTransition`
/// block below with:
///   Lottie.asset('assets/lottie/splash.json', width: 160, repeat: false)
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  @override
  void initState() {
    super.initState();
    // TODO: once auth state is checked here, route to /home, /login, or
    // straight into the app for an already-signed-in user instead of
    // always landing on /login.
    Timer(const Duration(milliseconds: 1400), () {
      if (mounted) context.go('/login');
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
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: _scale,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shopping_basket_rounded,
                  color: AppColors.primary,
                  size: 56,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'أسواق الطيبات',
              style: AppTextStyles.h1.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
