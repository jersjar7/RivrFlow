// lib/features/auth/presentation/pages/auth_wrapper.dart

import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:rivrflow/features/auth/providers/auth_provider.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';

enum AuthPageType { login, register, forgotPassword }

class AuthWrapper extends StatefulWidget {
  final Widget? authenticatedChild;
  final AuthPageType initialPage;

  const AuthWrapper({
    super.key,
    this.authenticatedChild,
    this.initialPage = AuthPageType.login,
  });

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper>
    with TickerProviderStateMixin {
  late AuthPageType _currentPage;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;

    // Setup page transition animation
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeInOut,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _switchToPage(AuthPageType page) {
    if (_currentPage == page) return;

    setState(() {
      _currentPage = page;
    });

    // Restart animation for smooth transition
    _animationController.reset();
    _animationController.forward();
  }

  void _switchToLogin() => _switchToPage(AuthPageType.login);
  void _switchToRegister() => _switchToPage(AuthPageType.register);
  void _switchToForgotPassword() => _switchToPage(AuthPageType.forgotPassword);

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case AuthPageType.login:
        return LoginPage(
          onSwitchToRegister: _switchToRegister,
          onSwitchToForgotPassword: _switchToForgotPassword,
        );
      case AuthPageType.register:
        return RegisterPage(onSwitchToLogin: _switchToLogin);
      case AuthPageType.forgotPassword:
        return ForgotPasswordPage(onBackToLogin: _switchToLogin);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        // Show loading while initializing
        if (!authProvider.isInitialized) {
          return const CupertinoPageScaffold(
            child: Center(child: CupertinoActivityIndicator(radius: 20)),
          );
        }

        // Show authenticated content if user is signed in
        if (authProvider.isAuthenticated) {
          return widget.authenticatedChild ?? _buildDefaultAuthenticatedView();
        }

        // Show authentication pages with smooth transitions
        return SlideTransition(
          position: _slideAnimation,
          child: _buildCurrentPage(),
        );
      },
    );
  }

  Widget _buildDefaultAuthenticatedView() {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('RivrFlow'),
        trailing: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => authProvider.signOut(),
              child: Text(
                'Sign Out',
                style: TextStyle(
                  color: CupertinoTheme.of(context).primaryColor,
                  fontSize: 16,
                ),
              ),
            );
          },
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    CupertinoIcons.checkmark_circle,
                    size: 80,
                    color: CupertinoColors.systemGreen,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Welcome back!',
                    style: CupertinoTheme.of(
                      context,
                    ).textTheme.navLargeTitleTextStyle,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Hello ${authProvider.userDisplayName}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Text(
                    'This is a placeholder for your main app content.\nReplace this with your home page or main navigation.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: CupertinoColors.systemGrey2,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
