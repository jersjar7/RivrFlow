// lib/features/auth/providers/auth_provider.dart

import 'package:flutter/foundation.dart';
import 'package:rivrflow/features/auth/models/auth_user.dart';
import '../../../core/services/auth_service.dart';

/// Simple authentication state management for RivrFlow
class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  // State
  AuthUser? _currentUser;
  bool _isLoading = false;
  String _errorMessage = '';
  String _successMessage = '';
  bool _isInitialized = false;

  // Getters
  AuthUser? get currentUser => _currentUser;
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
    _authService.authStateChanges.listen((firebaseUser) {
      if (firebaseUser != null) {
        _currentUser = AuthUser.fromFirebaseUser(firebaseUser);
        print('AUTH_PROVIDER: User signed in: ${_currentUser!.uid}');
      } else {
        _currentUser = null;
        print('AUTH_PROVIDER: User signed out');
      }
      notifyListeners();
    });

    // Set current user if already signed in
    final firebaseUser = _authService.currentUser;
    if (firebaseUser != null) {
      _currentUser = AuthUser.fromFirebaseUser(firebaseUser);
    }

    _isInitialized = true;
    notifyListeners();
    print('AUTH_PROVIDER: Initialization complete');
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
      // Clear biometric cache
      _biometricAvailable = null;
      _biometricEnabled = null;
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

  /// Get user's display name
  String get userDisplayName {
    if (_currentUser?.displayName?.isNotEmpty == true) {
      return _currentUser!.displayName!;
    }
    return _currentUser?.email ?? 'User';
  }

  /// Get user's first name
  String get userFirstName => _currentUser?.firstName ?? '';

  /// Get user's last name
  String get userLastName => _currentUser?.lastName ?? '';
}
