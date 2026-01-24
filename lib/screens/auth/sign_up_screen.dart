import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_widgets.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.signUpWithEmail(
      _emailController.text,
      _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pop(); // Return to sign in screen
    } else if (!success && mounted) {
      _showError(authProvider.error ?? 'Sign up failed');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return LoadingOverlay(
            isLoading: authProvider.isLoading,
            message: 'Creating account...',
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppPadding.lg),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      // Header
                      Text(
                        'Join SnapNest',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create an account to start capturing memories',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 48),
                      // Email field
                      CustomTextField(
                        controller: _emailController,
                        labelText: 'Email',
                        hintText: 'Enter your email',
                        prefixIcon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!value.contains('@')) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Password field
                      CustomTextField(
                        controller: _passwordController,
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        suffixIcon: _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        onSuffixTap: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Confirm Password field
                      CustomTextField(
                        controller: _confirmPasswordController,
                        labelText: 'Confirm Password',
                        hintText: 'Confirm your password',
                        prefixIcon: Icons.lock_outline,
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        onSuffixTap: () {
                          setState(
                            () => _obscureConfirmPassword =
                                !_obscureConfirmPassword,
                          );
                        },
                        textInputAction: TextInputAction.done,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 32),
                      // Sign Up button
                      GradientButton(
                        text: 'Sign Up',
                        onPressed: _signUp,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF334155)],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Sign in link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: Color(0xFF14B8A6),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
