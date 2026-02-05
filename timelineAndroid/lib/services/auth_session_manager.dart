import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../config/sync_config.dart';

/// Authentication state
enum AuthState {
  signedOut,
  signedIn,
  signingIn,
  error,
}

/// OAuth token response
class TokenResponse {
  final String accessToken;
  final String refreshToken;
  
  TokenResponse({required this.accessToken, required this.refreshToken});
  
  factory TokenResponse.fromJson(Map<String, dynamic> json) {
    return TokenResponse(
      accessToken: json['access_token'] as String,  // Changed from 'accessToken'
      refreshToken: json['refresh_token'] as String,  // Changed from 'refreshToken'
    );
  }
}

/// Manages OAuth authentication and token storage
class AuthSessionManager extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  AuthState _state = AuthState.signedOut;
  String? _errorMessage;
  
  AuthState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isSignedIn => _state == AuthState.signedIn;
  
  // Storage keys
  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  
  AuthSessionManager() {
    _checkInitialAuthState();
  }
  
  /// Check if user is already signed in on app startup
  Future<void> _checkInitialAuthState() async {
    final token = await _storage.read(key: _keyAccessToken);
    if (token != null) {
      _state = AuthState.signedIn;
      notifyListeners();
    }
  }
  
  /// Start OAuth login flow
  Future<void> login() async {
    try {
      _state = AuthState.signingIn;
      _errorMessage = null;
      notifyListeners();
      
      final uri = Uri.parse(SyncConfig.oauthStartUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch OAuth URL');
      }
    } catch (e) {
      _state = AuthState.error;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
  
  /// Handle OAuth callback with authorization code
  Future<bool> handleCallback(Uri callbackUri) async {
    print('handleCallback called with URI: $callbackUri');
    final code = callbackUri.queryParameters['code'];
    print('Extracted code: $code');
    
    if (code == null) {
      print('ERROR: No code in callback URI');
      _state = AuthState.error;
      _errorMessage = 'No authorization code in callback';
      notifyListeners();
      return false;
    }
    return await exchangeCodeForTokens(code);
  }
  
  /// Exchange authorization code for tokens (for manual code entry)
  Future<bool> exchangeCodeForTokens(String code) async {
    try {
      print('exchangeCodeForTokens called with code: $code');
      _state = AuthState.signingIn;
      _errorMessage = null;
      notifyListeners();
      
      print('Making POST request to: ${SyncConfig.oauthExchangeUrl}');
      print('Headers: Content-Type=application/json, X-API-Key=${SyncConfig.apiKey}');
      print('Body: ${json.encode({'code': code})}');
      
      // Exchange code for tokens
      final response = await http.post(
        Uri.parse(SyncConfig.oauthExchangeUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': SyncConfig.apiKey,
        },
        body: json.encode({'code': code}),
      );
      
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode != 200) {
        throw Exception('Token exchange failed: ${response.body}');
      }
      
      final tokenResponse = TokenResponse.fromJson(json.decode(response.body));
      print('Token response parsed successfully');
      
      // Store tokens securely
      await _storage.write(key: _keyAccessToken, value: tokenResponse.accessToken);
      await _storage.write(key: _keyRefreshToken, value: tokenResponse.refreshToken);
      print('Tokens stored securely');
      
      _state = AuthState.signedIn;
      _errorMessage = null;
      notifyListeners();
      print('Auth state set to signedIn');
      
      return true;
    } catch (e) {
      print('ERROR in exchangeCodeForTokens: $e');
      _state = AuthState.error;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  /// Get current access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: _keyAccessToken);
  }
  
  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _keyRefreshToken);
  }
  
  /// Refresh access token using refresh token
  Future<bool> refreshAccessToken() async {
    try {
      final refreshToken = await getRefreshToken();
      if (refreshToken == null) {
        throw Exception('No refresh token available');
      }
      
      final response = await http.post(
        Uri.parse(SyncConfig.oauthRefreshUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': SyncConfig.apiKey,
        },
        body: json.encode({'refreshToken': refreshToken}),
      );
      
      if (response.statusCode != 200) {
        // Refresh failed, sign out user
        await signOut();
        return false;
      }
      
      final tokenResponse = TokenResponse.fromJson(json.decode(response.body));
      
      // Update stored tokens
      await _storage.write(key: _keyAccessToken, value: tokenResponse.accessToken);
      await _storage.write(key: _keyRefreshToken, value: tokenResponse.refreshToken);
      
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }
  
  /// Sign out and clear tokens
  Future<void> signOut() async {
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
    
    _state = AuthState.signedOut;
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
