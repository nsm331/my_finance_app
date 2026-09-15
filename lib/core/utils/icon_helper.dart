import 'package:flutter/material.dart';

/// Helper class to provide compile-time constant icons and map icon codes
/// to constant IconData instances. This avoids dynamic IconData allocations
/// which break Flutter's font tree-shaking in release builds.
class AppIcons {
  AppIcons._();

  /// Curated list of category icons for the category creator/picker UI
  static const List<IconData> availableCategoryIcons = [
    Icons.receipt_long_rounded,
    Icons.restaurant_rounded,
    Icons.directions_car_rounded,
    Icons.shopping_bag_rounded,
    Icons.medical_services_rounded,
    Icons.home_rounded,
    Icons.school_rounded,
    Icons.sports_esports_rounded,
    Icons.account_balance_rounded,
    Icons.storefront_rounded,
    Icons.laptop_mac_rounded,
    Icons.trending_up_rounded,
    Icons.flight_rounded,
    Icons.pets_rounded,
    Icons.fitness_center_rounded,
    Icons.build_rounded,
    Icons.work_rounded,
    Icons.coffee_rounded,
    Icons.local_gas_station_rounded,
    Icons.card_giftcard_rounded,
    Icons.savings_rounded,
    Icons.handshake_rounded,
    Icons.currency_exchange_rounded,
    Icons.shopping_cart_rounded,
    Icons.fastfood_rounded,
    Icons.phone_android_rounded,
    Icons.wifi_rounded,
    Icons.electric_bolt_rounded,
    Icons.water_drop_rounded,
    Icons.local_hospital_rounded,
    Icons.credit_card_rounded,
    Icons.payments_rounded,
    Icons.attach_money_rounded,
    Icons.monetization_on_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.family_restroom_rounded,
    Icons.celebration_rounded,
    Icons.child_care_rounded,
    Icons.movie_rounded,
    Icons.music_note_rounded,
    Icons.local_laundry_service_rounded,
    Icons.cleaning_services_rounded,
    Icons.two_wheeler_rounded,
    Icons.directions_bus_rounded,
    Icons.more_horiz_rounded,
    Icons.category_rounded,
  ];

  /// Curated list of wallet/account icons
  static const List<IconData> availableWalletIcons = [
    Icons.account_balance_wallet_rounded, // محفظة عامة
    Icons.payments_rounded,              // نقد / كاش
    Icons.account_balance_rounded,       // بنك / حساب مصرفي
    Icons.credit_card_rounded,           // بطاقة ائتمان / صراف
    Icons.phone_android_rounded,         // محفظة إلكترونية
    Icons.savings_rounded,               // حصالة / ادخار
    Icons.lock_rounded,                  // خزنة / أمان
    Icons.storefront_rounded,            // متجر / صندوق المحل
    Icons.work_rounded,                  // عمل / راتب
    Icons.monetization_on_rounded,       // فكة / مصاريف جيب
    Icons.star_rounded,                  // محفظة خاصة / مميزة
    Icons.trending_up_rounded,           // استثمار / تداول
    Icons.family_restroom_rounded,       // محفظة المنزل / العائلة
    Icons.shopping_bag_rounded,          // مشتريات / تسوق
    Icons.card_giftcard_rounded,         // هدايا / مكافآت
    Icons.currency_exchange_rounded,     // صرافة وتحويل
  ];

  /// Curated color palette for wallets
  static const List<Color> availableWalletColors = [
    Color(0xFF0D9488), // Teal (الافتراضي)
    Color(0xFF10B981), // Emerald (كاش / نقد)
    Color(0xFF0284C7), // Sky Blue (بنك)
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF6366F1), // Indigo
    Color(0xFF7C3AED), // Violet
    Color(0xFF9333EA), // Purple
    Color(0xFFD946EF), // Fuchsia
    Color(0xFFF43F5E), // Rose
    Color(0xFFEF4444), // Red
    Color(0xFFF97316), // Orange
    Color(0xFFF59E0B), // Amber / Gold (ادخار)
    Color(0xFF84CC16), // Lime
    Color(0xFF06B6D4), // Cyan
    Color(0xFF64748B), // Slate
    Color(0xFF1E293B), // Dark Slate
  ];

  /// Default icon code for wallets (Icons.account_balance_wallet_rounded)
  static final int defaultWalletIconCode = Icons.account_balance_wallet_rounded.codePoint;

  /// Default color for wallets
  static const int defaultWalletColorValue = 0xFF0D9488;

  /// Static map of code points to constant IconData objects
  static final Map<int, IconData> _iconMap = {
    // Dynamic mapping from availableCategoryIcons
    for (final icon in availableCategoryIcons) icon.codePoint: icon,
    for (final icon in availableWalletIcons) icon.codePoint: icon,

    // Legacy standard Material icon codepoints mapping
    0xe5d8: Icons.receipt_long,
    0xe56c: Icons.restaurant,
    0xe1d7: Icons.directions_car,
    0xe59c: Icons.shopping_bag,
    0xe3e3: Icons.medical_services,
    0xe318: Icons.home,
    0xe559: Icons.school,
    0xe5e7: Icons.sports_esports,
    0xe040: Icons.account_balance,
    0xe5f9: Icons.storefront,
    0xe37a: Icons.laptop_mac,
    0xe66e: Icons.trending_up,
    0xe25a: Icons.flight,
    0xe472: Icons.pets,
    0xe153: Icons.fitness_center,
    0xe566: Icons.build,
    0xe1be: Icons.currency_exchange,
    0xe28e: Icons.handshake,
    0xe897: Icons.category,
    0xe5d2: Icons.more_horiz,
  };

  /// Safely resolves an icon code point to a constant IconData.
  /// Falls back to [Icons.category_rounded] if codePoint is unknown or null.
  static IconData getIcon(int? codePoint) {
    if (codePoint == null || codePoint == 0) {
      return Icons.category_rounded;
    }
    return _iconMap[codePoint] ?? Icons.category_rounded;
  }
}
