import 'package:flutter/material.dart';

const Map<String, IconData> kCategoryIcons = {
  'restaurant': Icons.restaurant,
  'directions_car': Icons.directions_car,
  'shopping_bag': Icons.shopping_bag,
  'receipt_long': Icons.receipt_long,
  'movie': Icons.movie,
  'favorite': Icons.favorite,
  'school': Icons.school,
  'home': Icons.home,
  'payments': Icons.payments,
  'category': Icons.category,
};

class Category {
  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.keywords = '',
  });

  final int? id;
  final String name;
  final String icon;
  final int color;

  /// Từ khóa KHÔNG DẤU, lowercase, ngăn cách bằng dấu phẩy.
  final String keywords;

  Color get colorValue => Color(color);
  IconData get iconData => kCategoryIcons[icon] ?? Icons.category;
  List<String> get keywordList =>
      keywords.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'keywords': keywords,
      };

  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int?,
        name: m['name'] as String,
        icon: m['icon'] as String,
        color: m['color'] as int,
        keywords: (m['keywords'] as String?) ?? '',
      );
}
