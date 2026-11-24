import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'api_service.dart';

/// Lets AuthService clear pushed screens (dialogs, sheets, detail pages) on logout.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// App-wide signals so screens can react to changes made elsewhere.
class AppEvents {
  AppEvents._();

  /// Bumped whenever vehicles or transactions change (deal started, completed,
  /// cancelled, vehicle created/edited/deleted). Lists listen and refetch.
  static final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);
  static void dataChanged() => dataVersion.value++;

  /// Bottom navigation index: 0 showroom, 1 transactions, 2 profile.
  static final ValueNotifier<int> selectedTab = ValueNotifier<int>(0);
}

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  static const _tokenKey = 'auth_token';

  User? _user;
  bool _ready = false;

  User? get user => _user;
  bool get isReady => _ready;
  bool get isLoggedIn => _user != null;

  /// Restores a saved session. Call once before runApp.
  Future<void> init() async {
    api.onUnauthorized = () => unawaited(logout());
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_tokenKey);
    if (saved != null) {
      api.token = saved;
      try {
        _user = await api.getMe();
      } on ApiException catch (e) {
        api.token = null;
        // Only forget the token when the server says it is no longer valid;
        // keep it if we were merely offline.
        if (e.statusCode == 401 || e.statusCode == 404) {
          await prefs.remove(_tokenKey);
        }
      }
    }
    _ready = true;
    notifyListeners();
  }

  Future<void> _startSession(AuthResult r) async {
    api.token = r.token;
    _user = r.user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, r.token);
    notifyListeners();
  }

  Future<void> login(String email, String password) async =>
      _startSession(await api.login(email, password));

  Future<void> register(String username, String email, String password) async =>
      _startSession(await api.register(username, email, password));

  void updateUser(User u) {
    _user = u;
    notifyListeners();
  }

  Future<void> logout() async {
    api.token = null;
    _user = null;
    AppEvents.selectedTab.value = 0;
    // Drop any pushed routes so the login screen (home) is what the user sees.
    rootNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }
}
