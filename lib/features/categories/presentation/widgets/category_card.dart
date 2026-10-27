import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../home/domain/entities/category.dart';
import 'category_image.dart';

/// A square photo card with the category name underneath.
class CategoryCard extends StatelessWidget {
  const CategoryCard({super.key, required this.category, required this.onTap});

  final Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: category.nameAr,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          children: [
            Expanded(
              // A soft tile the picture sits on: isolated product shots (white
              // background) blend into it, photos get a tidy rounded frame.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.tile,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: SizedBox.expand(child: CategoryImage(imageUrl: category.imageUrl)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              category.nameAr,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
