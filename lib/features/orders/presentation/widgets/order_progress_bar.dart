import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../cart/domain/entities/fulfillment.dart';
import '../../domain/entities/order_status.dart';

const _deliveryLabels = ['تم الاستلام', 'قيد التحضير', 'في الطريق', 'تم التسليم'];
const _pickupLabels = ['تم الاستلام', 'قيد التحضير', 'جاهز', 'تم الاستلام من الفرع'];

/// Four bars under the arrival time: finished stages are navy, the current one
/// red, the rest grey — with the stage names underneath.
class OrderProgressBar extends StatelessWidget {
  const OrderProgressBar({super.key, required this.status, this.orderType = OrderType.delivery});

  final OrderStatus status;
  final OrderType orderType;

  static ValueKey<String> segmentKey(int index) => ValueKey('progress-segment-$index');

  @override
  Widget build(BuildContext context) {
    final labels = orderType == OrderType.pickup ? _pickupLabels : _deliveryLabels;
    final current = status.step;
    final delivered = status == OrderStatus.delivered;

    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: segmentKey(i),
                  height: 6,
                  decoration: BoxDecoration(
                    color: delivered || i < current
                        ? AppColors.primary
                        : (i == current ? AppColors.accent : AppColors.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  labels[i],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    height: 1.2,
                    fontWeight: i == current && !delivered ? FontWeight.w800 : FontWeight.w600,
                    color: i <= current || delivered ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
