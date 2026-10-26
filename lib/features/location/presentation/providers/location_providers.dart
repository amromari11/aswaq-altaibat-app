import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/supabase_providers.dart';
import '../../data/repositories/addresses_repository.dart';
import '../../data/repositories/zones_repository.dart';
import '../../data/services/location_service.dart';
import '../../domain/entities/delivery_zone.dart';
import '../../domain/entities/saved_address.dart';

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final zonesRepositoryProvider = Provider<ZonesRepository>((ref) {
  return ZonesRepository(ref.watch(supabaseClientProvider));
});

final addressesRepositoryProvider = Provider<AddressesRepository>((ref) {
  return AddressesRepository(ref.watch(supabaseClientProvider));
});

/// Active delivery zones from Supabase, in display order.
final zonesProvider = FutureProvider<List<DeliveryZone>>((ref) {
  return ref.watch(zonesRepositoryProvider).fetchActive();
});

/// Zone lookup by id; null while zones are loading, on error, or for an id
/// that's no longer active.
final zoneByIdProvider = Provider.family<DeliveryZone?, String?>((ref, id) {
  final zones = ref.watch(zonesProvider).valueOrNull ?? const [];
  for (final zone in zones) {
    if (zone.id == id) return zone;
  }
  return null;
});

/// Saved delivery addresses — same model as the cart: local state is the
/// source of truth for the session, mirrored to `user_addresses` for
/// signed-in users (guests stay local-only; RLS needs a user_id). Unlike the
/// cart, signed-in writes go to the server *first* so local state always
/// holds real server ids (needed for `orders.address_id`); [upsert] throws
/// if that write fails, so the form can tell the user.
class SavedAddressesNotifier extends StateNotifier<List<SavedAddress>> {
  SavedAddressesNotifier(this._ref) : super(const []);

  final Ref _ref;

  AddressesRepository get _repository => _ref.read(addressesRepositoryProvider);
  String? get _userId => _ref.read(currentUserProvider)?.id;

  /// Adds or replaces (by id). The first address, or one flagged default,
  /// becomes the default and clears the flag on the others.
  Future<void> upsert(SavedAddress address) async {
    final makeDefault = address.isDefault || state.isEmpty;
    var saved = address.copyWith(isDefault: makeDefault);

    final userId = _userId;
    if (userId != null) {
      saved = saved.isPersisted
          ? await _repository.update(saved)
          : await _repository.insert(userId, saved);
    }

    state = [
      for (final a in state)
        if (a.id != address.id) makeDefault ? a.copyWith(isDefault: false) : a,
      saved,
    ];
  }

  void setDefault(String id) {
    final target = state.where((a) => a.id == id).firstOrNull;
    state = [for (final a in state) a.copyWith(isDefault: a.id == id)];
    if (target != null) _sync(target, (repo) => repo.setDefault(id));
  }

  void remove(String id) {
    final removed = state.where((a) => a.id == id).firstOrNull;
    final rest = state.where((a) => a.id != id).toList();
    if (removed != null && removed.isDefault && rest.isNotEmpty) {
      final promoted = rest[0] = rest[0].copyWith(isDefault: true);
      _sync(promoted, (repo) => repo.setDefault(promoted.id));
    }
    state = rest;
    if (removed != null) _sync(removed, (repo) => repo.delete(id));
  }

  /// Loads the signed-in user's saved addresses. Called on sign-in (and an
  /// already-authenticated launch), like the cart.
  ///
  /// Sign-in happens at the end of checkout, so addresses a guest added on
  /// this device are uploaded to their account first rather than dropped —
  /// and if checkout had one of them selected, the selection follows it to
  /// its new server id.
  Future<void> hydrateFromServer() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final selectedId = _ref.read(selectedAddressIdProvider);
      String? movedSelection;
      for (final local in state.where((a) => !a.isPersisted)) {
        final saved = await _repository.insert(userId, local);
        if (local.id == selectedId) movedSelection = saved.id;
      }
      state = await _repository.fetch(userId);
      if (movedSelection != null) {
        _ref.read(selectedAddressIdProvider.notifier).state = movedSelection;
      }
    } catch (_) {
      // Keep local state; the list just won't reflect the server this time.
    }
  }

  /// Sign-out: forget this user's addresses on this device without
  /// deleting them server-side.
  void clearLocalOnly() => state = const [];

  /// Fire-and-forget mirror of a write about [address] — only for a
  /// signed-in user's rows that already exist server-side.
  void _sync(SavedAddress address, Future<void> Function(AddressesRepository repo) write) {
    if (_userId == null || !address.isPersisted) return;
    unawaited(write(_repository).catchError((_) {}));
  }
}

final savedAddressesProvider = StateNotifierProvider<SavedAddressesNotifier, List<SavedAddress>>(
  (ref) => SavedAddressesNotifier(ref),
);

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
  return ref.watch(zoneByIdProvider(address.zoneId));
});
