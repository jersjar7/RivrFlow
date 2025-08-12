// lib/features/auth/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:rivrflow/features/auth/models/auth_user.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/user_settings.dart';
import '../../auth/services/user_settings_service.dart';

/// Simple authentication state management for RivrFlow
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final UserSettingsService _userSettingsService = UserSettingsService();

  // State
  AuthUser? _currentUser;
  UserSettings? _currentUserSettings;
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  bool _isInitialized = false;

  // Getters
  AuthUser? get currentUser => _currentUser;
  UserSettings? get currentUserSettings => _currentUserSettings;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  String get successMessage => _successMessage;
  bool get isInitialized => _isInitialized;

  // Biometric capabilities (cached)
  bool? _biometricAvailable;
  bool? _biometricEnabled;

  /// Initialize the provider
  Future<void> initialize() async {
    print('AUTH_PROVIDER: Initializing...');

    // Listen to auth state changes
    _authService.authStateChanges.listen((firebaseUser) async {
      if (firebaseUser != null) {
        _currentUser = AuthUser.fromFirebaseUser(firebaseUser);
        print('AUTH_PROVIDER: User signed in: ${_currentUser!.uid}');

        // Fetch user settings
        await _loadUserSettings();
      } else {
        _currentUser = null;
        _currentUserSettings = null;
        print('AUTH_PROVIDER: User signed out');
      }
      notifyListeners();
    });

    // Set current user if already signed in
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      _currentUser = AuthUser.fromFirebaseUser(firebaseUser);
      await _loadUserSettings();
    }

    _isInitialized = true;
    notifyListeners();
    print('AUTH_PROVIDER: Initialization complete');
  }

  /// Load user settings from Firestore
  Future<void> _loadUserSettings() async {
    if (_currentUser == null) return;

    try {
      print('AUTH_PROVIDER: Loading user settings for: ${_currentUser!.uid}');
      _currentUserSettings = await _userSettingsService.getUserSettings(
        _currentUser!.uid,
      );
      print('AUTH_PROVIDER: User settings loaded successfully');
    } catch (e) {
      print('AUTH_PROVIDER: Error loading user settings: $e');
      // Don't throw - user can still use the app without settings
      _currentUserSettings = null;
    }
  }

  /// Refresh user settings (call this after updating settings elsewhere)
  Future<void> refreshUserSettings() async {
    await _loadUserSettings();
    notifyListeners();
  }

  // MARK: - Authentication Methods

  /// Sign in with email and password
  Future<bool> signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      _setError('Please enter both email and password');
      return false;
    }

    _setLoading(true);
    _clearMessages();

    final result = await _authService.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    _setLoading(false);

    if (result.isSuccess) {
      _setSuccess('Signed in successfully');
      return true;
    } else {
      _setError(result.error ?? 'Sign in failed');
      return false;
    }
  }

  /// Register with email and password
  Future<bool> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    if (email.trim().isEmpty ||
        password.isEmpty ||
        firstName.trim().isEmpty ||
        lastName.trim().isEmpty) {
      _setError('Please fill in all required fields');
      return false;
    }

    _setLoading(true);
    _clearMessages();

    final result = await _authService.registerWithEmailAndPassword(
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );

    _setLoading(false);

    if (result.isSuccess) {
      _setSuccess('Account created successfully');
      return true;
    } else {
      _setError(result.error ?? 'Registration failed');
      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordReset(String email) async {
    if (email.trim().isEmpty) {
      _setError('Please enter your email address');
      return false;
    }

    _setLoading(true);
    _clearMessages();

    final result = await _authService.sendPasswordResetEmail(email: email);

    _setLoading(false);

    if (result.isSuccess) {
      _setSuccess('Password reset email sent');
      return true;
    } else {
      _setError(result.error ?? 'Failed to send reset email');
      return false;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    _setLoading(true);

    final result = await _authService.signOut();

    _setLoading(false);

    if (result.isSuccess) {
      // Clear biometric cache and user settings
      _biometricAvailable = null;
      _biometricEnabled = null;
      _currentUserSettings = null;
      _setSuccess('Signed out successfully');
    } else {
      _setError(result.error ?? 'Sign out failed');
    }
  }

  // MARK: - Biometric Authentication

  /// Check if biometric authentication is available
  Future<bool> get isBiometricAvailable async {
    _biometricAvailable ??= await _authService.isBiometricAvailable();
    return _biometricAvailable!;
  }

  /// Check if biometric login is enabled
  Future<bool> get isBiometricEnabled async {
    _biometricEnabled ??= await _authService.isBiometricEnabled();
    return _biometricEnabled!;
  }

  /// Enable biometric login
  Future<bool> enableBiometric() async {
    if (!isAuthenticated) {
      _setError('Please sign in first');
      return false;
    }

    _setLoading(true);
    _clearMessages();

    final result = await _authService.enableBiometricLogin();

    _setLoading(false);

    if (result.isSuccess) {
      _biometricEnabled = true; // Update cache
      _setSuccess('Biometric login enabled');
      return true;
    } else {
      _setError(result.error ?? 'Failed to enable biometric login');
      return false;
    }
  }

  /// Disable biometric login
  Future<bool> disableBiometric() async {
    _setLoading(true);
    _clearMessages();

    final result = await _authService.disableBiometricLogin();

    _setLoading(false);

    if (result.isSuccess) {
      _biometricEnabled = false; // Update cache
      _setSuccess('Biometric login disabled');
      return true;
    } else {
      _setError(result.error ?? 'Failed to disable biometric login');
      return false;
    }
  }

  /// Sign in with biometrics
  Future<bool> signInWithBiometric() async {
    _setLoading(true);
    _clearMessages();

    final result = await _authService.signInWithBiometrics();

    _setLoading(false);

    if (result.isSuccess) {
      _setSuccess('Biometric sign in successful');
      return true;
    } else {
      _setError(result.error ?? 'Biometric sign in failed');
      return false;
    }
  }

  // MARK: - User Information Getters

  /// Get user's display name (fallback to email if no name available)
  String get userDisplayName {
    if (_currentUserSettings != null) {
      final fullName = _currentUserSettings!.fullName;
      if (fullName.isNotEmpty) return fullName;
    }

    if (_currentUser?.displayName?.isNotEmpty == true) {
      return _currentUser!.displayName!;
    }

    return _currentUser?.email ?? 'User';
  }

  /// Get user's first name from UserSettings
  String get userFirstName {
    return _currentUserSettings?.firstName ?? _currentUser?.firstName ?? '';
  }

  /// Get user's last name from UserSettings
  String get userLastName {
    return _currentUserSettings?.lastName ?? _currentUser?.lastName ?? '';
  }

  /// Get formatted user name for display (e.g., "Santiago T.")
  String get userDisplayNameShort {
    final firstName = userFirstName;
    final lastName = userLastName;

    if (firstName.isEmpty) {
      return _currentUser?.email.split('@').first ?? 'User';
    }

    if (lastName.isEmpty) {
      return firstName;
    }

    // Return "FirstName L." format
    return '$firstName ${lastName.substring(0, 1).toUpperCase()}.';
  }

  /// Get user's full name from UserSettings
  String get userFullName {
    return _currentUserSettings?.fullName ?? userDisplayName;
  }

  // MARK: - Helper Methods

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _successMessage = '';
    notifyListeners();
    print('AUTH_PROVIDER: Error - $error');
  }

  void _setSuccess(String message) {
    _successMessage = message;
    _errorMessage = '';
    notifyListeners();
    print('AUTH_PROVIDER: Success - $message');
  }

  void _clearMessages() {
    _errorMessage = '';
    _successMessage = '';
    notifyListeners();
  }

  /// Clear all messages (called from UI)
  void clearMessages() {
    _clearMessages();
  }

  /// Check if the current error suggests user should retry
  bool get shouldRetry {
    return _errorMessage.contains('network') ||
        _errorMessage.contains('connection') ||
        _errorMessage.contains('timeout');
  }
}
