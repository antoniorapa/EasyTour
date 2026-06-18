import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static String? currentUserId;
  static String? currentUsername;
  static String? currentEmail;
  static String? currentRole;
  static String? authToken;

  static bool get isLoggedIn {
    return currentUserId != null && currentUserId!.isNotEmpty;
  }

  static Future<void> saveSession({
    required String userId,
    required String username,
    required String email,
    required String role,
    String? token,
  }) async {
    currentUserId = userId;
    currentUsername = username;
    currentEmail = email;
    currentRole = role;
    authToken = token;

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('currentUserId', userId);
    await prefs.setString('currentUsername', username);
    await prefs.setString('currentEmail', email);
    await prefs.setString('currentRole', role);

    if (token != null && token.isNotEmpty) {
      await prefs.setString('authToken', token);
    }
  }

  static Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();

    currentUserId = prefs.getString('currentUserId');
    currentUsername = prefs.getString('currentUsername');
    currentEmail = prefs.getString('currentEmail');
    currentRole = prefs.getString('currentRole');
    authToken = prefs.getString('authToken');

    return isLoggedIn;
  }

  static Future<void> clearSession() async {
    currentUserId = null;
    currentUsername = null;
    currentEmail = null;
    currentRole = null;
    authToken = null;

    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('currentUserId');
    await prefs.remove('currentUsername');
    await prefs.remove('currentEmail');
    await prefs.remove('currentRole');
    await prefs.remove('authToken');
  }

  static Future<void> logout() async {
    await clearSession();
  }
}