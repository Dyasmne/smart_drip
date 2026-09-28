import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/helpers.dart';
import '../../routes/app_routes.dart';
import '../../widgets/common/custom_button.dart';
import '../../widgets/common/custom_textfield.dart';

/// SmartDrip Registration Screen
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ============================================================
  // SMARTDRIP BACKGROUND
  // ============================================================

  // Use this same background color for the other authentication
  // screens so the Login and Register screens look consistent.
  static const Color _backgroundColor = Color(0xFFF1F8F3);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    final authProvider = context.read<AuthProvider>();

    final success = await authProvider.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      // IMPORTANT:
      // Do NOT navigate to Home/Dashboard here.
      //
      // Registration creates the Firebase account, then
      // AuthProvider signs the user out.
      //
      // We return to the Login screen instead.

      AppHelpers.showSnackBar(
        context,
        'Account created successfully! Please sign in.',
      );

      // Go back to the Login screen.
      //
      // Register screen is normally opened from Login, so
      // popping this screen returns directly to Login.
      Navigator.pop(context);
    } else {
      AppHelpers.showSnackBar(
        context,
        authProvider.error ??
            'Registration failed. Please try again.',
        isError: true,
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,

      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  const Expanded(
                    child: Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  // Balance the back button.
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ==================================================
            // SCROLLABLE CONTENT
            // ==================================================

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // ==================================================
                    // REGISTER ICON
                    // ==================================================

                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF2E7D32),
                            Color(0xFF66BB6A),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primary.withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_add_outlined,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ==================================================
                    // TITLE
                    // ==================================================

                    const Text(
                      'Join SmartDrip',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),

                    const SizedBox(height: 6),

                    const Text(
                      'Create your account to monitor your irrigation system',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 30),

                    // ==================================================
                    // FORM CARD
                    // ==================================================

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.primary.withOpacity(0.10),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            // ==========================================
                            // FULL NAME
                            // ==========================================

                            CustomTextField(
                              label: 'Full Name',
                              hint: 'Enter your full name',
                              controller: _nameController,
                              prefixIcon: Icons.person_outline,
                              validator: (value) {
                                if (value == null ||
                                    value.trim().isEmpty) {
                                  return 'Please enter your full name';
                                }

                                if (value.trim().length < 2) {
                                  return 'Name must be at least 2 characters';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // ==========================================
                            // EMAIL
                            // ==========================================

                            CustomTextField(
                              label: 'Email Address',
                              hint: 'Enter your email',
                              controller: _emailController,
                              keyboardType:
                                  TextInputType.emailAddress,
                              prefixIcon: Icons.email_outlined,
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty) {
                                  return 'Please enter your email';
                                }

                                if (!AppHelpers.isValidEmail(
                                  value,
                                )) {
                                  return 'Please enter a valid email';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // ==========================================
                            // PASSWORD
                            // ==========================================

                            CustomTextField(
                              label: 'Password',
                              hint: 'Create a strong password',
                              controller: _passwordController,
                              isPassword: true,
                              prefixIcon: Icons.lock_outline,
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty) {
                                  return 'Please enter a password';
                                }

                                if (!AppHelpers.isValidPassword(
                                  value,
                                )) {
                                  return 'Password must be at least 6 characters';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 16),

                            // ==========================================
                            // CONFIRM PASSWORD
                            // ==========================================

                            CustomTextField(
                              label: 'Confirm Password',
                              hint: 'Re-enter your password',
                              controller:
                                  _confirmPasswordController,
                              isPassword: true,
                              prefixIcon: Icons.lock_outline,
                              textInputAction:
                                  TextInputAction.done,
                              onEditingComplete: _handleRegister,
                              validator: (value) {
                                if (value == null ||
                                    value.isEmpty) {
                                  return 'Please confirm your password';
                                }

                                if (value !=
                                    _passwordController.text) {
                                  return 'Passwords do not match';
                                }

                                return null;
                              },
                            ),

                            const SizedBox(height: 28),

                            // ==========================================
                            // CREATE ACCOUNT BUTTON
                            // ==========================================

                            Consumer<AuthProvider>(
                              builder: (
                                context,
                                auth,
                                _,
                              ) {
                                return CustomButton(
                                  label: 'Create Account',
                                  onPressed: auth.isLoading
                                      ? null
                                      : _handleRegister,
                                  isLoading: auth.isLoading,
                                  leadingIcon:
                                      Icons.check_circle_outline,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // LOGIN LINK
                    // ==================================================

                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),

                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}