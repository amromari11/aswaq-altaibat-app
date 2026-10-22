import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/zones_repository.dart';
import '../../data/services/location_service.dart';
import '../../domain/entities/delivery_zone.dart';
import '../../domain/entities/saved_address.dart';

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final zonesRepositoryProvider = Provider<ZonesRepository>((ref) => const ZonesRepository());

final zonesProvider = Provider<List<DeliveryZone>>((ref) => ref.watch(zonesRepositoryProvider).all());

/// Saved delivery addresses. In-memory only for now (lost on app restart) —
/// the notifier's methods are the seam where a Supabase-backed repository
/// plugs in once the `user_addresses` table exists.
class SavedAddressesNotifier extends StateNotifier<List<SavedAddress>> {
  SavedAddressesNotifier() : super(const []);

  /// Adds or replaces (by id). The first address, or one flagged default,
  /// becomes the default and clears the flag on the others.
  void upsert(SavedAddress address) {
    final makeDefault = address.isDefault || state.isEmpty;
    final next = [
      for (final a in state)
        if (a.id != address.id) makeDefault ? a.copyWith(isDefault: false) : a,
      address.copyWith(isDefault: makeDefault),
    ];
    state = next;
  }

  void setDefault(String id) {
    state = [for (final a in state) a.copyWith(isDefault: a.id == id)];
  }

  void remove(String id) {
    final removed = state.where((a) => a.id == id).firstOrNull;
    final rest = state.where((a) => a.id != id).toList();
    if (removed != null && removed.isDefault && rest.isNotEmpty) {
      rest[0] = rest[0].copyWith(isDefault: true);
    }
    state = rest;
  }
}

final savedAddressesProvider =
    StateNotifierProvider<SavedAddressesNotifier, List<SavedAddress>>((ref) => SavedAddressesNotifier());

/// Address the customer picked in checkout this session; falls back to the
/// default saved address.
final selectedAddressIdProvider = StateProvider<String?>((ref) => null);

final selectedAddressProvider = Provider<SavedAddress?>((ref) {
  final addresses = ref.watch(savedAddressesProvider);
  final selectedId = ref.watch(selectedAddressIdProvider);
  for (final a in addresses) {
    if (a.id == selectedId) return a;
  }
  for (final a in addresses) {
    if (a.isDefault) return a;
  }
  return null;
});

final selectedZoneProvider = Provider<DeliveryZone?>((ref) {
  final address = ref.watch(selectedAddressProvider);
  if (address == null) return null;
  return ref.watch(zonesRepositoryProvider).byId(address.zoneId);
});
