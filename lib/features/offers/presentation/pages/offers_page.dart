import 'package:flutter/material.dart';

import '../../../../core/widgets/coming_soon_view.dart';

class OffersPage extends StatelessWidget {
  const OffersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العروض')),
      body: const ComingSoonView(
        message: 'كل عروض الأسبوع في مكان واحد قريباً',
        icon: Icons.local_offer_outlined,
      ),
    );
  }
}
