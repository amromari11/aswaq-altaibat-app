import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/store_settings_repository.dart';
import '../../domain/entities/fulfillment.dart';
import '../../domain/services/slot_planner.dart';

final storeSettingsRepositoryProvider = Provider<StoreSettingsRepository>((ref) {
  return StoreSettingsRepository(ref.watch(supabaseClientProvider));
});

/// Null when the server has no store settings yet (delivery now only).
final storeSettingsProvider = FutureProvider<StoreSettings?>((ref) {
  return ref.watch(storeSettingsRepositoryProvider).fetch();
});

final slotPlannerProvider = Provider<SlotPlanner?>((ref) {
  final settings = ref.watch(storeSettingsProvider).valueOrNull;
  return settings == null ? null : SlotPlanner(settings);
});

/// The current time; overridden in tests so slots and opening hours are predictable.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Delivery or pickup, chosen on the checkout screen.
final orderTypeProvider = StateProvider.autoDispose<OrderType>((ref) => OrderType.delivery);

/// False = as soon as possible; true = at [scheduledSlotProvider].
final wantsScheduleProvider = StateProvider.autoDispose<bool>((ref) => false);

final scheduledSlotProvider = StateProvider.autoDispose<TimeSlot?>((ref) => null);
