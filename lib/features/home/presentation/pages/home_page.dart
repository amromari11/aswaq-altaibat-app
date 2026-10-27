import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/curved_header_clipper.dart';
import '../../../categories/presentation/providers/selected_category_provider.dart';
import '../../domain/entities/product.dart';
import '../providers/home_providers.dart';
import '../widgets/banner_carousel.dart';
import '../widgets/category_bubble_row.dart';
import '../widgets/home_brand_bar.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/location_header.dart';
import '../widgets/order_again_row.dart';
import '../widgets/product_grid.dart';
import '../../../recommendations/presentation/providers/recommendations_providers.dart';
import '../../../recommendations/presentation/widgets/recommendations_row.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: HomeBrandBar()),
        SliverToBoxAdapter(child: _buildHeader()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildBanners(),
              const SizedBox(height: 24),
              _buildCategories(),
              const SizedBox(height: 24),
              _buildOrderAgain(),
              _buildProductSection(),
              const SizedBox(height: 24),
              RecommendationsRow(title: 'قد يعجبك أيضاً', provider: homeRecommendationsProvider),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return ClipPath(
      clipper: const CurvedHeaderClipper(),
      child: Container(
        // Top inset is handled by HomeBrandBar above this, not here.
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        decoration: const BoxDecoration(gradient: AppColors.headerGradient),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const LocationHeader(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.notifications_none, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            HomeSearchBar(
              onChanged: (value) => ref.read(searchQueryProvider.notifier).state = value,
              onSubmitted: (value) => ref.read(searchQueryProvider.notifier).state = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanners() {
    final banners = ref.watch(homeBannersProvider);
    return banners.when(
      data: (data) => BannerCarousel(banners: data),
      loading: () => const _ShimmerBlock(height: 150, borderRadius: 16),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCategories() {
    final categories = ref.watch(categoriesProvider);
    final selectedId = ref.watch(selectedCategoryProvider);
    return categories.when(
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        return CategoryBubbleRow(
          categories: data,
          selectedCategoryId: selectedId,
          onSelected: (category) {
            ref.read(selectedCategoryProvider.notifier).state =
                selectedId == category.id ? null : category.id;
          },
        );
      },
      loading: () => const _ShimmerBlock(height: 92, borderRadius: 12),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildOrderAgain() {
    final orderAgain = ref.watch(orderAgainProvider);
    return orderAgain.maybeWhen(
      data: (products) {
        if (products.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(title: 'اطلب مرة أخرى'),
            const SizedBox(height: 12),
            OrderAgainRow(products: products),
            const SizedBox(height: 24),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  /// Section header + grid together, because which title applies depends on
  /// the same branching (search / category / offers-vs-fallback) that picks
  /// the grid's data source — keeping them in one method avoids the two
  /// drifting out of sync.
  Widget _buildProductSection() {
    final query = ref.watch(searchQueryProvider);
    if (query.trim().isNotEmpty) {
      return _productSection(
        title: 'نتائج البحث',
        asyncProducts: ref.watch(searchResultsProvider),
        emptyMessage: 'لا توجد نتائج لبحثك.',
      );
    }

    final selectedCategoryId = ref.watch(selectedCategoryProvider);
    if (selectedCategoryId != null) {
      return _productSection(
        title: 'المنتجات',
        asyncProducts: ref.watch(categoryProductsProvider(selectedCategoryId)),
        emptyMessage: 'لا توجد منتجات في هذا القسم.',
      );
    }

    final weeklyOffers = ref.watch(weeklyOffersProvider);

    // No weekly offers configured yet — fall back to general browsing so
    // the catalog is still visible by default instead of an empty state.
    if (weeklyOffers.hasValue && weeklyOffers.value!.isEmpty) {
      return _productSection(
        title: 'تصفح منتجاتنا',
        asyncProducts: ref.watch(latestProductsProvider),
        emptyMessage: 'لا توجد منتجات حالياً.',
      );
    }

    return _productSection(
      title: 'عروض هذا الأسبوع',
      asyncProducts: weeklyOffers,
      emptyMessage: 'لا توجد عروض حالياً.',
    );
  }

  Widget _productSection({
    required String title,
    required AsyncValue<List<Product>> asyncProducts,
    required String emptyMessage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
        const SizedBox(height: 12),
        asyncProducts.when(
          data: (products) => _productGridOrEmpty(products, emptyMessage),
          loading: () => const _ShimmerGrid(),
          error: (_, __) => const _ErrorMessage(),
        ),
      ],
    );
  }

  Widget _productGridOrEmpty(List<Product> products, String emptyMessage) {
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(emptyMessage, style: AppTextStyles.body),
        ),
      );
    }
    return ProductGrid(products: products);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTextStyles.h2);
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({required this.height, required this.borderRadius});

  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.border,
      highlightColor: AppColors.background,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemBuilder: (context, index) => const _ShimmerBlock(height: 260, borderRadius: 16),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'تعذر تحميل البيانات. تحقق من الاتصال وحاول مرة أخرى.',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
