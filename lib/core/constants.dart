import 'package:flutter/material.dart';

/// Model mặc định (người dùng đổi được trong Cài đặt, không hardcode trong logic gọi API).
const String kDefaultGeminiModel = 'gemini-2.5-flash';
const double kLowConfidence = 0.7;

/// Chỉ dùng khi dev: flutter run --dart-define=GEMINI_API_KEY=xxxx
const String kDevApiKey = String.fromEnvironment('GEMINI_API_KEY');

const String kOtherCategory = 'Khác';
const String kIncomeCategory = 'Thu nhập';

class AppColors {
  static const green = Color(0xFF1B5E20);
  static const lime = Color(0xFFA5E05A);
  static const bgLight = Color(0xFFF2F5F0);
  static const bgDark = Color(0xFF0F1A10);
  static const good = Color(0xFF2E9E4F);
  static const bad = Color(0xFFE53935);
}
