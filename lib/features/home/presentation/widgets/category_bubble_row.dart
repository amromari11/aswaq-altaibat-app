import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../categories/presentation/widgets/category_image.dart';
import '../../domain/entities/category.dart';

/// Compact category selector: five rounded tiles fit the width, the rest scroll
/// sideways. Each tile is a square picture with a bold two-line name underneath.
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

  /// Tiles that fill the viewport on a phone.
  static const visibleCount = 5;
  static const _gap = 8.0;
  static const _maxTile = 92.0; // keeps tiles tidy on tablets / desktop (more than 5 show there)
  static const _labelSize = 11.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tile = math.min(
          (constraints.maxWidth - _gap * (visibleCount - 1)) / visibleCount,
          _maxTile,
        );
        // Two label lines at the user's text size, so a larger system font grows the row
        // instead of overflowing it.
        final labelHeight = MediaQuery.textScalerOf(context).scale(_labelSize) * 1.7 * 2;

        return SizedBox(
          height: tile + 6 + labelHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: _gap),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category.id == selectedCategoryId;

              return Semantics(
                button: true,
                selected: isSelected,
                label: category.nameAr,
                child: GestureDetector(
                  onTap: () => onSelected(category),
                  child: SizedBox(
                    width: tile,
                    child: Column(
                      children: [
                        Container(
                          width: tile,
                          height: tile,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: AppColors.tile,
                            border: Border.all(
                              color: isSelected ? AppColors.primary : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: SizedBox.expand(
                              child: CategoryImage(imageUrl: category.imageUrl, cacheWidth: 160),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            category.nameAr,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: _labelSize,
                              height: 1.3,
                              fontWeight: FontWeight.w800,
                              color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
