import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/category.dart';

/// Circular bubble category selector (ألبان، منظفات، خضار وفواكه، ...).
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
      height: 92,
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
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.primary : AppColors.primaryLight,
                      border: isSelected
                          ? Border.all(color: AppColors.primaryDark, width: 2)
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: category.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: category.imageUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (context, _, __) => _fallbackIcon(isSelected),
                          )
                        : _fallbackIcon(isSelected),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.nameAr,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
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

  Widget _fallbackIcon(bool isSelected) {
    return Icon(
      Icons.local_grocery_store_outlined,
      color: isSelected ? Colors.white : AppColors.primary,
    );
  }
}
