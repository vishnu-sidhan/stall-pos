import 'package:flutter/material.dart';
import 'item_category.dart';
export 'dietary_type.dart';

/// Base contract for any domain entity having a unique identifier and human-readable display name.
abstract interface class IdentifiableEntity {
  String get id;
  String get displayName;
}

/// Reusable mixin providing standardized dietary classification and inference.
///
/// Any class using this mixin provides [dietaryType] and [displayName],
/// and automatically inherits a robust [effectiveDietaryType] implementation that
/// prioritizes explicit user classification and falls back to dynamic keyword inference.
mixin DietaryAware {
  ItemDietaryType? get dietaryType;
  String get displayName;
  String? get categoryName => null;

  ItemDietaryType get effectiveDietaryType {
    if (dietaryType != null && dietaryType != ItemDietaryType.none) {
      return dietaryType!;
    }
    return ItemDietaryType.infer(name: displayName, category: categoryName);
  }
}

/// Reusable mixin providing standardized theme color resolution.
///
/// Any class using this mixin provides [colorHex] and [displayName],
/// and automatically provides [resolvedColorHex] (falling back to the dynamic category palette)
/// and a Material [Color].
mixin ColorThemed {
  int? get colorHex;
  String get displayName;

  /// Effective color hex value, resolving to the dynamic category palette if unset.
  int get resolvedColorHex =>
      colorHex ?? ItemCategory.getColorForCategory(displayName);

  /// Material [Color] representation of [resolvedColorHex].
  Color get color => Color(resolvedColorHex);
}

/// Contract for catalog entities that can be priced and ordered.
abstract interface class CatalogItem implements IdentifiableEntity {
  double get price;
  bool get isAvailable;
}

/// Contract for items rendered in kitchen preparation views (e.g. order cards, consolidated queue).
abstract interface class PreparationItem implements IdentifiableEntity {
  String get category;
  int? get colorHex;
}
