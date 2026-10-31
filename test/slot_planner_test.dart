import 'package:aswaq_altaibat/features/cart/domain/entities/fulfillment.dart';
import 'package:aswaq_altaibat/features/cart/domain/services/slot_planner.dart';
import 'package:flutter_test/flutter_test.dart';

const _settings = StoreSettings(
  branchName: 'فرع الزرقاء',
  branchAddress: 'الزرقاء',
  latitude: 32.07,
  longitude: 36.09,
  opensAtMinutes: 8 * 60,
  closesAtMinutes: 23 * 60,
);

/// An instant given as Amman wall-clock time (UTC+3).
DateTime amman(int y, int m, int d, int h, [int min = 0]) =>
    DateTime.utc(y, m, d, h, min).subtract(const Duration(hours: 3));

StoreSettings _with({int? slot, int? lead, int? days, bool? scheduling, int? closes}) =>
    StoreSettings(
      branchName: _settings.branchName,
      branchAddress: _settings.branchAddress,
      latitude: _settings.latitude,
      longitude: _settings.longitude,
      opensAtMinutes: _settings.opensAtMinutes,
      closesAtMinutes: closes ?? _settings.closesAtMinutes,
      slotMinutes: slot ?? 60,
      minLeadMinutes: lead ?? 60,
      maxDaysAhead: days ?? 2,
      schedulingEnabled: scheduling ?? true,
    );

void main() {
  const planner = SlotPlanner(_settings);

  test('open from opening time up to (not including) closing time, Amman time', () {
    expect(planner.isOpenAt(amman(2026, 11, 2, 7, 59)), isFalse);
    expect(planner.isOpenAt(amman(2026, 11, 2, 8, 0)), isTrue);
    expect(planner.isOpenAt(amman(2026, 11, 2, 22, 59)), isTrue);
    expect(planner.isOpenAt(amman(2026, 11, 2, 23, 0)), isFalse);
  });

  test('a store that closes at midnight is open at 23:59', () {
    expect(SlotPlanner(_with(closes: 1440)).isOpenAt(amman(2026, 11, 2, 23, 59)), isTrue);
  });

  test('mid-morning: today from the first slot after the lead time, then two more days', () {
    final days = planner.days(amman(2026, 11, 2, 10, 30));
    expect(days.map((d) => d.label), ['اليوم', 'غداً', 'الأربعاء 4/11']);
    expect(days.first.slots.first.start, amman(2026, 11, 2, 12),
        reason: '11:00 is inside the 60-minute lead');
    expect(SlotPlanner.slotLabel(days.first.slots.first), '12:00 – 13:00');
    expect(SlotPlanner.slotLabel(days.first.slots.last), '22:00 – 23:00',
        reason: 'the last slot ends at closing');
    expect(days[1].slots, hasLength(15), reason: '08:00 … 22:00, hourly');
  });

  test('late evening: today has nothing left, so tomorrow comes first', () {
    final days = planner.days(amman(2026, 11, 2, 22, 30));
    expect(days.first.label, 'غداً');
    expect(days.first.slots.first.start, amman(2026, 11, 3, 8));
  });

  test('30-minute slots double the choices', () {
    final days = SlotPlanner(_with(slot: 30)).days(amman(2026, 11, 2, 6));
    expect(days.first.slots, hasLength(30));
    expect(SlotPlanner.slotLabel(days.first.slots.last), '22:30 – 23:00');
  });

  test('max days ahead and the scheduling switch are respected', () {
    expect(SlotPlanner(_with(days: 0)).days(amman(2026, 11, 2, 9)).map((d) => d.label), ['اليوم']);
    expect(SlotPlanner(_with(scheduling: false)).days(amman(2026, 11, 2, 9)), isEmpty);
  });

  test('a slot picked earlier stops being offered once it is inside the lead time', () {
    final slot = planner.days(amman(2026, 11, 2, 10, 30)).first.slots.first; // 12:00
    expect(planner.isStillOffered(slot, amman(2026, 11, 2, 10, 59)), isTrue);
    expect(planner.isStillOffered(slot, amman(2026, 11, 2, 11, 15)), isFalse);
  });

  test('describe says which day and which window', () {
    final now = amman(2026, 11, 2, 10, 30);
    final days = planner.days(now);
    expect(planner.describe(days.first.slots.first, now), 'اليوم 12:00 – 13:00');
    expect(planner.describe(days[1].slots.first, now), 'غداً 08:00 – 09:00');
  });

  test('works the same whatever time zone the phone is set to', () {
    // The same instant expressed in the phone's local time gives the same slots.
    final now = amman(2026, 11, 2, 10, 30);
    expect(planner.days(now.toLocal()).first.slots.first.start,
        planner.days(now).first.slots.first.start);
  });

  group('StoreSettings.fromJson', () {
    test('reads the row, including a midnight close', () {
      final s = StoreSettings.fromJson({
        'branch_name_ar': 'فرع',
        'branch_address_ar': 'عنوان',
        'branch_phone': null,
        'latitude': 32.073313,
        'longitude': 36.095312,
        'opens_at': '08:00:00',
        'closes_at': '24:00:00',
        'pickup_enabled': false,
        'scheduling_enabled': true,
        'slot_minutes': 30,
        'min_lead_minutes': 45,
        'max_days_ahead': 1,
        'pickup_ready_minutes': 15,
      });
      expect(s.opensAtMinutes, 480);
      expect(s.closesAtMinutes, 1440);
      expect(s.hoursLabel, '08:00 – 24:00');
      expect(s.pickupEnabled, isFalse);
      expect(
          (s.slotMinutes, s.minLeadMinutes, s.maxDaysAhead, s.pickupReadyMinutes), (30, 45, 1, 15));
    });
  });

  test('OrderType wire values match the database', () {
    expect(OrderType.pickup.wire, 'pickup');
    expect(OrderType.fromWire('pickup'), OrderType.pickup);
    expect(OrderType.fromWire(null), OrderType.delivery);
  });
}
