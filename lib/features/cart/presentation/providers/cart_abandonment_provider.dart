import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/local_notifications_service.dart';
import 'cart_provider.dart';

/// Side-effect-only provider: watch it once near the app root (see
/// AswaqAltaibatApp) to keep it alive for the app's lifetime. It reacts to
/// cart item count changes and schedules/cancels the abandoned-cart
/// reminder accordingly — no UI reads this provider's own value.
final cartAbandonmentWatcherProvider = Provider<void>((ref) {
  ref.listen<int>(cartItemCountProvider, (previous, next) {
    if (next > 0) {
      LocalNotificationsService.instance.scheduleAbandonedCartReminder();
    } else {
      LocalNotificationsService.instance.cancelAbandonedCartReminder();
    }
  }, fireImmediately: true);
});
