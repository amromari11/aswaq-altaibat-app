import '../entities/fulfillment.dart';

/// Works out the time slots the customer can pick, and whether "now" is
/// possible, from [settings] — the same rules `place_order` checks
/// (backend migration 015), so a slot offered here is a slot it accepts.
///
/// Amman is UTC+3 all year (Jordan stopped changing clocks in 2022), so the
/// store's wall clock is a fixed offset; no time-zone database needed.
class SlotPlanner {
  const SlotPlanner(this.settings);

  final StoreSettings settings;

  static const ammanOffset = Duration(hours: 3);

  static const _weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد'
  ];

  /// [instant] as Amman wall-clock time (a UTC-flagged DateTime holding the local reading).
  static DateTime wall(DateTime instant) => instant.toUtc().add(ammanOffset);

  /// An Amman wall-clock reading back to the real instant.
  static DateTime instant(DateTime wallTime) =>
      DateTime.utc(wallTime.year, wallTime.month, wallTime.day, wallTime.hour, wallTime.minute)
          .subtract(ammanOffset);

  /// '10:00' in Amman time.
  static String clockOf(DateTime instant) =>
      StoreSettings.clock(wall(instant).hour * 60 + wall(instant).minute);

  /// '10:00 – 11:00'.
  static String slotLabel(TimeSlot slot) => '${clockOf(slot.start)} – ${clockOf(slot.end)}';

  /// The store takes "now" orders only while it is open.
  bool isOpenAt(DateTime now) {
    final w = wall(now);
    final minute = w.hour * 60 + w.minute;
    return minute >= settings.opensAtMinutes && minute < settings.closesAtMinutes;
  }

  /// Every pickable slot from today up to `maxDaysAhead` days ahead; days with
  /// no slot left (today, late in the evening) are skipped.
  List<SlotDay> days(DateTime now) {
    if (!settings.schedulingEnabled) return const [];
    final today = wall(now);
    final earliest = now.toUtc().add(Duration(minutes: settings.minLeadMinutes));
    final result = <SlotDay>[];
    for (var offset = 0; offset <= settings.maxDaysAhead; offset++) {
      final date = DateTime.utc(today.year, today.month, today.day + offset);
      final slots = <TimeSlot>[];
      for (var m = settings.opensAtMinutes;
          m + settings.slotMinutes <= settings.closesAtMinutes;
          m += settings.slotMinutes) {
        final start = instant(date.add(Duration(minutes: m)));
        if (start.isBefore(earliest)) continue;
        slots.add(TimeSlot(start: start, end: start.add(Duration(minutes: settings.slotMinutes))));
      }
      if (slots.isNotEmpty) result.add(SlotDay(label: _dayLabel(date, offset), slots: slots));
    }
    return result;
  }

  /// Still offered right now (a slot picked a while ago may have slipped into the lead time).
  bool isStillOffered(TimeSlot slot, DateTime now) =>
      days(now).any((day) => day.slots.contains(slot));

  /// 'اليوم 10:00 – 11:00', 'غداً …', 'السبت 2/11 …'.
  String describe(TimeSlot slot, DateTime now) => '${dayOf(slot.start, now)} ${slotLabel(slot)}';

  /// 'اليوم 10:00', 'غداً 08:00', 'السبت 7/11 10:00' — for a time already chosen
  /// (an order's slot), without needing the store settings.
  static String moment(DateTime instant, DateTime now) =>
      '${dayOf(instant, now)} ${clockOf(instant)}';

  /// 'اليوم' / 'غداً' / 'السبت 7/11' for [instant], relative to [now], in Amman time.
  static String dayOf(DateTime instant, DateTime now) {
    final today = wall(now);
    final day = wall(instant);
    final date = DateTime.utc(day.year, day.month, day.day);
    final offset = date.difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    return _dayLabel(date, offset);
  }

  static String _dayLabel(DateTime date, int offset) {
    if (offset == 0) return 'اليوم';
    if (offset == -1) return 'أمس';
    if (offset == 1) return 'غداً';
    return '${_weekdays[date.weekday - 1]} ${date.day}/${date.month}';
  }
}
