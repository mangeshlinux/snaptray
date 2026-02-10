import 'package:flutter/material.dart';
import 'package:snappath_tray/shared/supabase_auth_service.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  final bool isWindows;

  const AuthScreen({
    super.key,
    required this.onLoginSuccess,
    this.isWindows = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = SupabaseAuthService();

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isForgotPassword = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    bool success = false;
    String message = "";

    try {
      if (_isForgotPassword) {
        success = await _authService.resetPassword(_emailController.text);
        message = success
            ? "Reset link sent to email"
            : "Error sending reset link";
        if (success) {
          setState(() => _isForgotPassword = false);
        }
      } else if (_tabController.index == 0) {
        // Login
        success = await _authService.login(
          _emailController.text,
          _passwordController.text,
        );
        message = success ? "Welcome back!" : "Invalid credentials";
      } else {
        // Sign Up
        success = await _authService.signUp(
          _emailController.text,
          _passwordController.text,
        );
        message = success
            ? "Account created! Please check email."
            : "Sign up failed";
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        if (success && !_isForgotPassword) {
          widget.onLoginSuccess();
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Sophisticated, muted accent colors
    final primaryColor = widget.isWindows
        ? const Color(0xFF6366F1) // Indigo
        : const Color(0xFF10B981); // Emerald

    // Modern gradient backgrounds that respect theme
    final backgroundGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              const Color(0xFF1A1B1E), // Deep charcoal
              const Color(0xFF25262B), // Slightly lighter charcoal
              Color.lerp(
                const Color(0xFF25262B),
                primaryColor,
                0.08,
              )!, // Subtle accent
            ]
          : [
              const Color(0xFFF8F9FA), // Soft off-white
              const Color(0xFFF1F3F5), // Light gray
              Color.lerp(
                const Color(0xFFF1F3F5),
                primaryColor,
                0.03,
              )!, // Very subtle accent
            ],
    );

    // Card styling with glass morphism effect
    final cardColor = isDark
        ? const Color(0xFF25262B).withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.9);

    final cardBorder = isDark
        ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1)
        : Border.all(color: primaryColor.withValues(alpha: 0.08), width: 1);

    final cardShadow = BoxShadow(
      color: isDark
          ? Colors.black.withValues(alpha: 0.3)
          : primaryColor.withValues(alpha: 0.08),
      blurRadius: isDark ? 20 : 30,
      offset: const Offset(0, 10),
      spreadRadius: isDark ? 0 : -5,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: backgroundGradient),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo with subtle glow
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  ),
                  child: Icon(
                    widget.isWindows
                        ? Icons.monitor_rounded
                        : Icons.smartphone_rounded,
                    size: 48,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isForgotPassword
                      ? "Reset Password"
                      : (_tabController.index == 0
                            ? "Welcome Back"
                            : "Create Account"),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Card with glass morphism
                Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [cardShadow],
                    border: cardBorder,
                  ),
                  child: Column(
                    children: [
                      if (!_isForgotPassword)
                        TabBar(
                          controller: _tabController,
                          indicatorColor: primaryColor,
                          labelColor: primaryColor,
                          unselectedLabelColor: Colors.grey,
                          dividerColor: Colors.transparent, // Cleaner look
                          onTap: (index) => setState(() {}),
                          tabs: const [
                            Tab(text: "Login"),
                            Tab(text: "Sign Up"),
                          ],
                        ),
                      const SizedBox(height: 24),

                      // Fields
                      TextField(
                        controller: _emailController,
                        style: TextStyle(color: colorScheme.onSurface),
                        decoration: InputDecoration(
                          labelText: "Email",
                          labelStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: primaryColor.withValues(alpha: 0.7),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? Colors.white.withValues(alpha: 0.03)
                              : Colors.grey.withValues(alpha: 0.03),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // REMOVED Phone Controller logic here
                      if (!_isForgotPassword)
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: TextStyle(color: colorScheme.onSurface),
                          decoration: InputDecoration(
                            labelText: "Password",
                            labelStyle: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: primaryColor.withValues(alpha: 0.7),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: primaryColor,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.03)
                                : Colors.grey.withValues(alpha: 0.03),
                          ),
                        ),

                      const SizedBox(height: 24),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _isLoading ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _isForgotPassword
                                      ? "Send Reset Link"
                                      : (_tabController.index == 0
                                            ? "Login"
                                            : "Sign Up"),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      if (!_isForgotPassword && _tabController.index == 0)
                        TextButton(
                          onPressed: () =>
                              setState(() => _isForgotPassword = true),
                          child: Text(
                            "Forgot Password?",
                            style: TextStyle(color: colorScheme.secondary),
                          ),
                        ),
                      if (_isForgotPassword)
                        TextButton(
                          onPressed: () =>
                              setState(() => _isForgotPassword = false),
                          child: Text(
                            "Back to Login",
                            style: TextStyle(color: colorScheme.secondary),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
