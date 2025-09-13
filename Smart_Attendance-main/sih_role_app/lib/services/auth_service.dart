import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static const _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userRoleKey = 'user_role';
  static const String _userIdKey = 'user_id';

  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: _userRoleKey);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  static Future<void> saveUserInfo(String role, String userId) async {
    await _storage.write(key: _userRoleKey, value: role);
    await _storage.write(key: _userIdKey, value: userId);
  }

  static Future<void> clearAuth() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userRoleKey);
    await _storage.delete(key: _userIdKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    if (token != null) {
      return {'Authorization': 'Bearer $token'};
    }
    return {};
  }

  static Future<AuthResult> login({
    required String username,
    required String password,
    required String role,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final userId = data['user_id'];

        await saveToken(token);
        await saveUserInfo(role, userId);

        return AuthResult.success(token, role, userId);
      } else {
        final error = jsonDecode(response.body);
        return AuthResult.error(error['detail'] ?? 'Login failed');
      }
    } catch (e) {
      return AuthResult.error('Network error: $e');
    }
  }

  static Future<AuthResult> register({
    required String username,
    required String password,
    required String role,
    required String name,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'role': role,
          'name': name,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'];
        final userId = data['user_id'];

        await saveToken(token);
        await saveUserInfo(role, userId);

        return AuthResult.success(token, role, userId);
      } else {
        final error = jsonDecode(response.body);
        return AuthResult.error(error['detail'] ?? 'Registration failed');
      }
    } catch (e) {
      return AuthResult.error('Network error: $e');
    }
  }

  static Future<void> logout() async {
    await clearAuth();
  }

  static Future<bool> validateToken() async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final headers = await getAuthHeaders();
      final response = await http.get(
        Uri.parse('http://localhost:8000/auth/validate'),
        headers: headers,
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}

class AuthResult {
  final bool isSuccess;
  final String? token;
  final String? role;
  final String? userId;
  final String? error;

  AuthResult.success(this.token, this.role, this.userId)
      : isSuccess = true,
        error = null;

  AuthResult.error(this.error)
      : isSuccess = false,
        token = null,
        role = null,
        userId = null;
}


