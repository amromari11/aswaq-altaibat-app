import 'package:flutter/material.dart';

import '../../../../core/widgets/coming_soon_view.dart';

/// Order history & tracking — reads from the `orders`/`order_items` tables
/// the admin dashboard already writes to. Stub until checkout exists on
/// this app (no point showing order history before orders can be placed).
class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('طلباتي')),
      body: const ComingSoonView(
        message: 'ستظهر طلباتك هنا بعد إتمام أول عملية شراء',
        icon: Icons.receipt_long_outlined,
      ),
    );
  }
}
