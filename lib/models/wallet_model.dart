import 'package:flutter/material.dart';
import '../core/utils/icon_helper.dart';

class WalletModel {
  final int? id;
  final String name;
  final int? _iconCode;
  final int? _colorValue;

  const WalletModel({
    this.id,
    required this.name,
    int? iconCode = 0xf534, // Icons.account_balance_wallet_rounded
    int? colorValue = 0xFF0D9488, // Primary Teal
  })  : _iconCode = iconCode ?? 0xf534,
        _colorValue = colorValue ?? 0xFF0D9488;

  int get iconCode => _iconCode ?? 0xf534;
  int get colorValue => _colorValue ?? 0xFF0D9488;

  IconData get iconData => AppIcons.getIcon(iconCode);
  Color get color => Color(colorValue);

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'icon_code': iconCode,
      'color_value': colorValue,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory WalletModel.fromMap(Map<dynamic, dynamic> map) {
    final rawId = map['id'];
    final rawIcon = map['icon_code'] ?? map['iconCode'];
    final rawColor = map['color_value'] ?? map['colorValue'];

    int parsedIcon = 0xf534;
    if (rawIcon is int) {
      parsedIcon = rawIcon;
    } else if (rawIcon is num) {
      parsedIcon = rawIcon.toInt();
    } else if (rawIcon != null) {
      parsedIcon = int.tryParse(rawIcon.toString()) ?? 0xf534;
    }

    int parsedColor = 0xFF0D9488;
    if (rawColor is int) {
      parsedColor = rawColor;
    } else if (rawColor is num) {
      parsedColor = rawColor.toInt();
    } else if (rawColor != null) {
      parsedColor = int.tryParse(rawColor.toString()) ?? 0xFF0D9488;
    }

    int? parsedId;
    if (rawId is int) {
      parsedId = rawId;
    } else if (rawId is num) {
      parsedId = rawId.toInt();
    } else if (rawId != null) {
      parsedId = int.tryParse(rawId.toString());
    }

    return WalletModel(
      id: parsedId,
      name: map['name']?.toString() ?? '',
      iconCode: parsedIcon,
      colorValue: parsedColor,
    );
  }

  WalletModel copyWith({
    int? id,
    String? name,
    int? iconCode,
    int? colorValue,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      iconCode: iconCode ?? this.iconCode,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WalletModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          iconCode == other.iconCode &&
          colorValue == other.colorValue;

  @override
  int get hashCode => Object.hash(id, name, iconCode, colorValue);

  @override
  String toString() =>
      'WalletModel(id: $id, name: $name, iconCode: $iconCode, colorValue: $colorValue)';
}
