import 'package:flutter/material.dart';

import '../../../../core/widgets/coming_soon_view.dart';

/// Full categories browser (all categories with their products) — stub for
/// now; the home tab's category bubbles already cover basic browsing.
class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الأقسام')),
      body: const ComingSoonView(message: 'صفحة الأقسام الكاملة قريباً'),
    );
  }
}
