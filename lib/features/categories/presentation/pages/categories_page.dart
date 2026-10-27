import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../home/presentation/providers/home_providers.dart';
import '../providers/selected_category_provider.dart';
import '../widgets/category_card.dart';

/// All categories as photo cards; tapping one shows its products on Home.
class CategoriesPage extends ConsumerWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('الأقسام')),
      body: categories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('تعذر تحميل الأقسام', style: AppTextStyles.body),
              TextButton(
                  onPressed: () => ref.invalidate(categoriesProvider),
                  child: const Text('إعادة المحاولة')),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(child: Text('لا توجد أقسام حالياً', style: AppTextStyles.body));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(categoriesProvider.future),
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150,
                mainAxisSpacing: 16,
                crossAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => CategoryCard(
                category: items[i],
                onTap: () {
                  ref.read(selectedCategoryProvider.notifier).state = items[i].id;
                  context.go('/home');
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
