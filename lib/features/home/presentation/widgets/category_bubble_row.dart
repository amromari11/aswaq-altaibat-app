import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../categories/presentation/widgets/category_image.dart';
import '../../domain/entities/category.dart';

/// Rounded-tile category selector (ألبان، منظفات، خضار وفواكه، ...).
class CategoryBubbleRow extends StatelessWidget {
  const CategoryBubbleRow({
    super.key,
    required this.categories,
    required this.onSelected,
    this.selectedCategoryId,
  });

  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<Category> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 64 tile + 6 gap + two lines of Cairo caption (~34) — 92 clipped
      // two-line names like "اجبان والبان ومشتقاتها" by 8px.
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category.id == selectedCategoryId;

          return GestureDetector(
            onTap: () => onSelected(category),
            child: SizedBox(
              width: 64,
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: AppColors.tile,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: SizedBox.expand(
                        child: CategoryImage(imageUrl: category.imageUrl, cacheWidth: 180),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Flexible so a larger system text scale shrinks the label
                  // area instead of overflowing the fixed-height row.
                  Flexible(
                    child: Text(
                      category.nameAr,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
