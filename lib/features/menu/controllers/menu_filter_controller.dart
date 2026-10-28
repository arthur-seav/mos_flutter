import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The Menu page's filters. Shared with Home, so tapping a category chip
/// or the search box on Home opens Menu already filtered.
@immutable
class MenuFilter {
  const MenuFilter({
    this.categoryId,
    this.query = '',
    this.isSearching = false,
  });

  /// Null means "All".
  final int? categoryId;

  /// Search text (TC-08). Matched against drink names.
  final String query;

  /// The search box is open on the Menu page.
  final bool isSearching;

  MenuFilter copyWith({
    int? Function()? categoryId,
    String? query,
    bool? isSearching,
  }) => MenuFilter(
    categoryId: categoryId != null ? categoryId() : this.categoryId,
    query: query ?? this.query,
    isSearching: isSearching ?? this.isSearching,
  );
}

final menuFilterProvider = NotifierProvider<MenuFilterController, MenuFilter>(
  MenuFilterController.new,
);

class MenuFilterController extends Notifier<MenuFilter> {
  @override
  MenuFilter build() => const MenuFilter();

  /// [categoryId] null selects "All".
  void selectCategory(int? categoryId) =>
      state = state.copyWith(categoryId: () => categoryId);

  /// Opening search starts from "All", so a drink is found whatever
  /// category was selected before. Chips can narrow it down again.
  void openSearch() =>
      state = state.copyWith(categoryId: () => null, isSearching: true);

  void setQuery(String query) => state = state.copyWith(query: query);

  void closeSearch() => state = state.copyWith(query: '', isSearching: false);
}
