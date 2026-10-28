import 'package:flutter/foundation.dart' show immutable;

/// A menu category (data dictionary: `categories`).
@immutable
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.sortOrder,
    this.isActive = true,
  });

  final int id;
  final String name;
  final int sortOrder;

  /// False = hidden from the menu (FR-25: admins deactivate categories).
  final bool isActive;
}
