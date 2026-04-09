import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_env.dart';

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, AuthSession?>(
      AuthSessionNotifier.new,
    );

class AuthSessionNotifier extends AsyncNotifier<AuthSession?> {
  static const _tokenKey = 'foreman_auth_token';
  static const _emailKey = 'foreman_auth_email';
  static const _mockTokenPrefix = 'mock-foreman-token';

  @override
  Future<AuthSession?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final email = prefs.getString(_emailKey);
    if (token == null || token.isEmpty) return null;
    return AuthSession(token: token, email: email ?? '');
  }

  Future<void> loginForeman({
    required String email,
    required String password,
  }) async {
    final current = state is AsyncData<AuthSession?>
        ? (state as AsyncData<AuthSession?>).value
        : null;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final token = await _requestToken(email: email, password: password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await prefs.setString(_emailKey, email);
      return AuthSession(token: token, email: email);
    });
    if (state.hasError && current != null) {
      state = AsyncData(current);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_emailKey);
    state = const AsyncData(null);
  }

  Future<String> _requestToken({
    required String email,
    required String password,
  }) async {
    if (AppEnv.authApiBaseUrl.isEmpty) {
      return _mockTokenForEmail(email, password);
    }

    final uri = Uri.parse(
      '${AppEnv.authApiBaseUrl.replaceAll(RegExp(r'/$'), '')}/foreman/login',
    );
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': password}),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Login failed (${response.statusCode}).');
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid login response.');
    }
    final token = (data['token'] ?? data['accessToken']) as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Missing access token in response.');
    }
    return token;
  }

  String _mockTokenForEmail(String email, String password) {
    if (email.isEmpty || password.isEmpty) {
      throw Exception('Please enter email and password.');
    }

    // Keep the mock lightweight while still rejecting obvious invalid input.
    if (!email.contains('@') || password.length < 3) {
      throw Exception('Invalid mock credentials. Use a valid email and password.');
    }

    final safeEmail = email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');
    return '$_mockTokenPrefix-$safeEmail';
  }
}

class AuthSession {
  const AuthSession({required this.token, required this.email});

  final String token;
  final String email;
}
