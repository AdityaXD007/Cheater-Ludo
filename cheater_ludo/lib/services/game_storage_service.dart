import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../game/engine/game_state.dart';

class GameStorageService {
  static const String _gameSaveKey = 'cheater_ludo_saved_game';

  static Future<void> saveGame(GameState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(state.toJson());
      await prefs.setString(_gameSaveKey, jsonString);
    } catch (e) {
      debugPrint('Failed to save game: $e');
    }
  }

  static Future<GameState?> loadGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_gameSaveKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString);
        return GameState.fromJson(json);
      }
    } catch (e) {
      debugPrint('Failed to load game: $e');
      // On parse failure, return null so we don't crash
      return null;
    }
    return null;
  }

  static Future<void> clearGame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_gameSaveKey);
    } catch (e) {
      debugPrint('Failed to clear game: $e');
    }
  }
}
