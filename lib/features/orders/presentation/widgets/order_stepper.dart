import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/order_status.dart';

/// The four stages a customer follows, in order.
const _steps = [
  (title: 'تم الاستلام', caption: 'استلمنا طلبك', icon: Icons.receipt_long),
  (title: 'قيد التحضير', caption: 'نجهّز منتجاتك', icon: Icons.shopping_basket),
  (title: 'خرج للتوصيل', caption: 'السائق في طريقه إليك', icon: Icons.delivery_dining),
  (title: 'تم التسليم', caption: 'وصل طلبك — بالهناء والعافية', icon: Icons.check_circle),
];

/// Vertical timeline: finished steps are filled with a check, the current step
/// is highlighted (with a gentle pulse), later steps are outlined.
class OrderStepper extends StatelessWidget {
  const OrderStepper({super.key, required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final current = status.step;
    final delivered = status == OrderStatus.delivered;

    return Column(
      children: [
        for (var i = 0; i < _steps.length; i++)
          _StepRow(
            key: ValueKey('order-step-$i'),
            title: _steps[i].title,
            caption: _steps[i].caption,
            icon: _steps[i].icon,
            // Delivered completes every step, including the last.
            state: i < current || delivered
                ? _StepState.done
                : i == current
                    ? _StepState.active
                    : _StepState.upcoming,
            isLast: i == _steps.length - 1,
            // The line below a step is "travelled" once the next step is reached.
            lineDone: i < current || delivered,
          ),
      ],
    );
  }
}

enum _StepState { done, active, upcoming }

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.title,
    required this.caption,
    required this.icon,
    required this.state,
    required this.isLast,
    required this.lineDone,
  });

  final String title;
  final String caption;
  final IconData icon;
  final _StepState state;
  final bool isLast;
  final bool lineDone;

  @override
  Widget build(BuildContext context) {
    final isActive = state == _StepState.active;
    final isDone = state == _StepState.done;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                _Dot(state: state, icon: icon),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: lineDone ? AppColors.primary : AppColors.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.w400,
                      color: isActive
                          ? AppColors.accent
                          : isDone
                              ? AppColors.primary
                              : AppColors.textMuted,
                    ),
                  ),
                  if (isActive || isDone)
                    Text(caption, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatefulWidget {
  const _Dot({required this.state, required this.icon});

  final _StepState state;
  final IconData icon;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the system "reduce motion" setting (and keep tests deterministic):
    // a perpetual animation otherwise never lets the UI settle.
    final animate = widget.state == _StepState.active && !MediaQuery.disableAnimationsOf(context);
    if (animate && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!animate && _pulse.isAnimating) {
      _pulse.stop();
    }
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) didChangeDependencies();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.state) {
      case _StepState.done:
        return _circle(fill: AppColors.primary, child: const Icon(Icons.check, color: Colors.white, size: 20));
      case _StepState.upcoming:
        return _circle(
          fill: AppColors.background,
          border: AppColors.border,
          child: Icon(widget.icon, color: AppColors.textMuted, size: 18),
        );
      case _StepState.active:
        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) => Stack(
            alignment: Alignment.center,
            children: [
              // Soft halo that breathes in and out.
              Container(
                width: 36 + 8 * _pulse.value,
                height: 36 + 8 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withValues(alpha: 0.18 * (1 - _pulse.value) + 0.06),
                ),
              ),
              child!,
            ],
          ),
          child: _circle(fill: AppColors.accent, child: Icon(widget.icon, color: Colors.white, size: 18)),
        );
    }
  }

  Widget _circle({required Color fill, Color? border, required Widget child}) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: border == null ? null : Border.all(color: border, width: 2),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
