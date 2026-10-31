import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/fulfillment.dart';
import '../../domain/services/slot_planner.dart';

/// [ توصيل للمنزل ] [ استلام من الفرع ]
class OrderTypeToggle extends StatelessWidget {
  const OrderTypeToggle({super.key, required this.value, required this.onChanged});

  final OrderType value;
  final ValueChanged<OrderType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<OrderType>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(
            value: OrderType.delivery,
            label: Text('توصيل للمنزل'),
            icon: Icon(Icons.delivery_dining_outlined),
          ),
          ButtonSegment(
            value: OrderType.pickup,
            label: Text('استلام من الفرع'),
            icon: Icon(Icons.storefront_outlined),
          ),
        ],
        selected: {value},
        onSelectionChanged: (selection) => onChanged(selection.first),
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: AppColors.primary,
          selectedForegroundColor: Colors.white,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          textStyle: AppTextStyles.bodyMedium,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

/// Where and when to collect a pickup order.
class PickupBranchCard extends StatelessWidget {
  const PickupBranchCard({super.key, required this.settings});

  final StoreSettings settings;

  Future<void> _openMap() async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '${settings.latitude},${settings.longitude}',
    });
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final phone = settings.branchPhone;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.storefront, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(settings.branchName, style: AppTextStyles.bodyMedium)),
            ],
          ),
          const SizedBox(height: 8),
          _InfoLine(icon: Icons.location_on_outlined, text: settings.branchAddress),
          _InfoLine(icon: Icons.access_time, text: 'ساعات العمل يومياً: ${settings.hoursLabel}'),
          _InfoLine(
            icon: Icons.inventory_2_outlined,
            text: 'يكون طلبك جاهزاً خلال ~${settings.pickupReadyMinutes} دقيقة من تأكيده',
          ),
          if (phone != null && phone.isNotEmpty)
            _InfoLine(icon: Icons.phone_outlined, text: phone, ltr: true),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _openMap,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('فتح الموقع في الخرائط'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text, this.ltr = false});

  final IconData icon;
  final String text;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textDirection: ltr ? TextDirection.ltr : null,
              textAlign: ltr ? TextAlign.end : null,
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// "As soon as possible" or a scheduled slot.
class TimeChoiceSection extends StatefulWidget {
  const TimeChoiceSection({
    super.key,
    required this.planner,
    required this.now,
    required this.orderType,
    required this.scheduled,
    required this.slot,
    required this.onAsap,
    required this.onSchedule,
    required this.onSlot,
    this.etaMinutes,
  });

  final SlotPlanner planner;
  final DateTime now;
  final OrderType orderType;

  /// True when "schedule" is chosen (or forced because the store is closed).
  final bool scheduled;
  final TimeSlot? slot;
  final int? etaMinutes;
  final VoidCallback onAsap;
  final VoidCallback onSchedule;
  final ValueChanged<TimeSlot> onSlot;

  @override
  State<TimeChoiceSection> createState() => _TimeChoiceSectionState();
}

class _TimeChoiceSectionState extends State<TimeChoiceSection> {
  int _day = 0;

  @override
  Widget build(BuildContext context) {
    final planner = widget.planner;
    final settings = planner.settings;
    final open = planner.isOpenAt(widget.now);
    final days = planner.days(widget.now);
    final pickup = widget.orderType == OrderType.pickup;
    final day = days.isEmpty ? null : days[_day.clamp(0, days.length - 1)];

    final String asapSubtitle;
    if (!open) {
      asapSubtitle = 'المتجر مغلق الآن (ساعات العمل ${settings.hoursLabel})';
    } else if (pickup) {
      asapSubtitle = 'جاهز للاستلام خلال ~${settings.pickupReadyMinutes} دقيقة';
    } else {
      asapSubtitle =
          widget.etaMinutes == null ? 'بأسرع ما يمكن' : 'خلال ~${widget.etaMinutes} دقيقة تقريباً';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChoiceTile(
          key: const ValueKey('time-asap'),
          icon: Icons.bolt_outlined,
          title: pickup ? 'استلام في أقرب وقت' : 'توصيل الآن',
          subtitle: asapSubtitle,
          selected: !widget.scheduled,
          enabled: open,
          onTap: widget.onAsap,
        ),
        if (days.isNotEmpty) ...[
          const SizedBox(height: 8),
          _ChoiceTile(
            key: const ValueKey('time-schedule'),
            icon: Icons.event_outlined,
            title: 'جدولة موعد',
            subtitle: widget.slot == null
                ? 'اختر اليوم والوقت المناسبين'
                : planner.describe(widget.slot!, widget.now),
            selected: widget.scheduled,
            enabled: true,
            onTap: widget.onSchedule,
          ),
        ],
        if (widget.scheduled && day != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < days.length; i++)
                ChoiceChip(
                  label: Text(days[i].label),
                  selected: days[i] == day,
                  onSelected: (_) => setState(() => _day = i),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final slot in day.slots)
                ChoiceChip(
                  key: ValueKey('slot-${slot.start.toUtc().toIso8601String()}'),
                  label: Text(SlotPlanner.slotLabel(slot), textDirection: TextDirection.ltr),
                  selected: slot == widget.slot,
                  selectedColor: AppColors.primaryLight,
                  onSelected: (_) => widget.onSlot(slot),
                ),
            ],
          ),
        ],
        if (days.isEmpty && !open)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'لا توجد مواعيد متاحة حالياً — حاول لاحقاً.',
              style: AppTextStyles.caption.copyWith(color: AppColors.accent),
            ),
          ),
      ],
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected && enabled;
    final color =
        !enabled ? AppColors.textMuted : (selected ? AppColors.primary : AppColors.textPrimary);
    return Semantics(
      button: true,
      selected: active,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: active ? AppColors.primary : AppColors.border, width: active ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyMedium.copyWith(color: color)),
                    Text(subtitle,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Icon(
                active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: active ? AppColors.primary : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
