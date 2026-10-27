import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The category currently filtering the home feed (null = no filter).
/// Shared so the Categories tab can send the shopper to a category on Home.
final selectedCategoryProvider = StateProvider<String?>((ref) => null);
