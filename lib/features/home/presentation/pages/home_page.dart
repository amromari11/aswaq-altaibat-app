import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../banners/presentation/banner_actions.dart';
import '../../../banners/presentation/providers/banner_providers.dart';
import '../../../banners/presentation/widgets/promo_banner_carousel.dart';
import '../../../categories/presentation/providers/selected_category_provider.dart';
import '../../../recommendations/presentation/providers/recommendations_providers.dart';
import '../../../recommendations/presentation/widgets/recommendations_row.dart';
import '../../../search/data/voice_search_service.dart';
import '../../../search/presentation/providers/search_input_providers.dart';
import '../../domain/entities/product.dart';
import '../providers/home_providers.dart';
import '../widgets/category_bubble_row.dart';
import '../widgets/delivery_header.dart';
import '../widgets/home_search_bar.dart';
import '../widgets/order_again_row.dart';
import '../widgets/product_grid.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _searchController = TextEditingController();
  late final VoiceSearchService _voice;
  bool _listening = false;
  bool _showAllBestSellers = false;

  /// Best sellers shown before "عرض الكل".
  static const _bestSellersPreview = 6;

  @override
  void initState() {
    super.initState();
    // Read here, not in dispose(): `ref` can't be used once the page is going away.
    _voice = ref.read(voiceSearchServiceProvider);
  }

  @override
  void dispose() {
    // Stop the microphone if the page goes away mid-sentence.
    if (_listening) _voice.stop();
    _searchController.dispose();
    super.dispose();
  }

  void _setSearch(String text) => ref.read(searchQueryProvider.notifier).state = text;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _toggleVoice() async {
    final voice = _voice;
    if (_listening) {
      await voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final started = await voice.start(
      onWords: (words, finished) {
        if (mounted && words.trim().isNotEmpty) _setSearch(words.trim());
      },
      onStopped: () {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (started) {
      setState(() => _listening = true);
    } else {
      _showMessage('البحث الصوتي غير متاح — اسمح باستخدام الميكروفون أو اكتب ما تبحث عنه.');
    }
  }

  Future<void> _scanBarcode() async {
    final code = await context.push<String>('/scan');
    if (code != null && code.trim().isNotEmpty && mounted) _setSearch(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(searchQueryProvider, (_, query) {
      if (_searchController.text != query) _searchController.text = query;
    });
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: DeliveryHeader()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: HomeSearchBar(
              controller: _searchController,
              listening: _listening,
              onChanged: _setSearch,
              onSubmitted: _setSearch,
              onVoice: _toggleVoice,
              onScan: _scanBarcode,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildBanners(),
              const SizedBox(height: 22),
              _buildCategories(),
              const SizedBox(height: 22),
              _buildOrderAgain(),
              _buildBestSellers(),
              _buildProductSection(),
              const SizedBox(height: 24),
              RecommendationsRow(title: 'قد يعجبك أيضاً', provider: homeRecommendationsProvider),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildBanners() {
    final banners = ref.watch(promoBannersProvider);
    return banners.when(
      data: (data) => PromoBannerCarousel(
        banners: data,
        onBannerTap: (banner) async {
          final messenger = ScaffoldMessenger.of(context);
          final opened = await openBanner(ref, banner);
          if (!opened && mounted) {
            messenger.showSnackBar(const SnackBar(content: Text('تعذر فتح هذا العرض حالياً')));
          }
        },
      ),
      loading: () => const _ShimmerBlock(height: 172, borderRadius: 24),
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
      loading: () => const _ShimmerBlock(height: 92, borderRadius: 16),
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

  /// "الأكثر مبيعاً": what other customers buy most (last 30 days). Hidden while
  /// searching or browsing a category, and when the server has none to show.
  Widget _buildBestSellers() {
    if (ref.watch(searchQueryProvider).trim().isNotEmpty || ref.watch(selectedCategoryProvider) != null) {
      return const SizedBox.shrink();
    }
    final best = ref.watch(bestSellersProvider).valueOrNull;
    if (best == null || best.isEmpty) return const SizedBox.shrink();

    final canExpand = best.length > _bestSellersPreview;
    final shown = _showAllBestSellers ? best : best.take(_bestSellersPreview).toList();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'الأكثر مبيعاً',
            actionLabel: canExpand ? (_showAllBestSellers ? 'عرض أقل' : 'عرض الكل') : null,
            onAction: () => setState(() => _showAllBestSellers = !_showAllBestSellers),
          ),
          const SizedBox(height: 12),
          ProductGrid(products: shown),
        ],
      ),
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
        // Not the same products again right under "الأكثر مبيعاً".
        exclude: {for (final p in ref.watch(bestSellersProvider).valueOrNull ?? const <Product>[]) p.id},
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
    Set<String> exclude = const {},
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: title),
        const SizedBox(height: 12),
        asyncProducts.when(
          data: (products) => _productGridOrEmpty(
            exclude.isEmpty ? products : products.where((p) => !exclude.contains(p.id)).toList(),
            emptyMessage,
          ),
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
  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTextStyles.h2.copyWith(fontWeight: FontWeight.w800))),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
            ),
            child: Text(actionLabel!, style: AppTextStyles.caption.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800)),
          ),
      ],
    );
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
        childAspectRatio: 0.62,
      ),
      itemBuilder: (context, index) => const _ShimmerBlock(height: 260, borderRadius: 20),
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
