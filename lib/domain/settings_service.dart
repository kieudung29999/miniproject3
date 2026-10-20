import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:receipt_tracker/core/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    this.apiKey,
    this.model = kDefaultGeminiModel,
    this.aiEnhanced = false,
    this.themeMode = ThemeMode.system,
    this.loaded = false,
  });

  final String? apiKey;
  final String model;
  final bool aiEnhanced;
  final ThemeMode themeMode;
  final bool loaded;

  bool get hasKey => apiKey != null && apiKey!.isNotEmpty;

  AppSettings copyWith({
    String? apiKey,
    bool clearKey = false,
    String? model,
    bool? aiEnhanced,
    ThemeMode? themeMode,
    bool? loaded,
  }) =>
      AppSettings(
        apiKey: clearKey ? null : (apiKey ?? this.apiKey),
        model: model ?? this.model,
        aiEnhanced: aiEnhanced ?? this.aiEnhanced,
        themeMode: themeMode ?? this.themeMode,
        loaded: loaded ?? this.loaded,
      );
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _load();
  }

  static const _storage = FlutterSecureStorage();
  static const _kKey = 'gemini_api_key';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    String? key;
    try {
      key = await _storage.read(key: _kKey);
    } catch (_) {}
    if ((key == null || key.isEmpty) && kDevApiKey.isNotEmpty) key = kDevApiKey;
    final t = (prefs.getInt('theme') ?? 0).clamp(0, ThemeMode.values.length - 1);
    state = AppSettings(
      apiKey: key,
      model: prefs.getString('model') ?? kDefaultGeminiModel,
      aiEnhanced: prefs.getBool('ai_enhanced') ?? false,
      themeMode: ThemeMode.values[t],
      loaded: true,
    );
  }

  Future<void> setApiKey(String key) async {
    final k = key.trim();
    if (k.isEmpty) return;
    await _storage.write(key: _kKey, value: k);
    state = state.copyWith(apiKey: k);
  }

  Future<void> clearApiKey() async {
    try {
      await _storage.delete(key: _kKey);
    } catch (_) {}
    state = state.copyWith(clearKey: true, aiEnhanced: false);
    (await SharedPreferences.getInstance()).setBool('ai_enhanced', false);
  }

  Future<void> setModel(String model) async {
    final m = model.trim().isEmpty ? kDefaultGeminiModel : model.trim();
    (await SharedPreferences.getInstance()).setString('model', m);
    state = state.copyWith(model: m);
  }

  Future<void> setAiEnhanced(bool v) async {
    (await SharedPreferences.getInstance()).setBool('ai_enhanced', v);
    state = state.copyWith(aiEnhanced: v);
  }

  Future<void> setThemeMode(ThemeMode m) async {
    (await SharedPreferences.getInstance()).setInt('theme', m.index);
    state = state.copyWith(themeMode: m);
  }
}
