import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/customer_info.dart';

const _nameKey = 'customer_name';
const _phoneKey = 'customer_phone';

/// The name + phone last used to order from this device, remembered so a
/// returning guest doesn't retype them (and the phone twice) every time.
/// Stored locally only; the server learns about the customer when an order is
/// placed (`place_order` upserts them by phone). Null until the first order.
class CustomerInfoNotifier extends AsyncNotifier<CustomerInfo?> {
  @override
  Future<CustomerInfo?> build() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString(_nameKey);
      final phone = prefs.getString(_phoneKey);
      if (name == null || phone == null) return null;
      return CustomerInfo(name: name, phone: phone);
    } catch (_) {
      // Storage unavailable (private window, blocked site data): behave as
      // if nothing was remembered.
      return null;
    }
  }

  Future<void> remember(CustomerInfo info) async {
    state = AsyncData(info);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_nameKey, info.name);
      await prefs.setString(_phoneKey, info.phone);
    } catch (_) {
      // Kept for this session in memory; just won't survive a restart.
    }
  }
}

final customerInfoProvider = AsyncNotifierProvider<CustomerInfoNotifier, CustomerInfo?>(CustomerInfoNotifier.new);
