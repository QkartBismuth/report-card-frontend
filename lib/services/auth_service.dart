import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user.dart';

class AuthService {
  static const _kToken = 'auth_token';
  static const _kUser = 'auth_user';

  Future<void> saveSession(String token, AppUser user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kToken, token);
    await prefs.setString(_kUser, jsonEncode({
          'user_id': user.id,
          'full_name': user.fullName,
          'role': user.role,
          'group_id': user.groupId,
        }));
  }

  Future<({String token, AppUser user})?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_kToken);
    final rawUser = prefs.getString(_kUser);
    if (token == null || rawUser == null) return null;
    return (token: token, user: AppUser.fromJson(jsonDecode(rawUser)));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kToken);
    await prefs.remove(_kUser);
  }
}