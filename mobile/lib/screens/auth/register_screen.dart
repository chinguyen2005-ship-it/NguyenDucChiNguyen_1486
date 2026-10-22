import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import 'login_screen.dart';
import 'verify_email_otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  final String initialRole;

  const RegisterScreen({super.key, this.initialRole = 'Parent'});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _authService = AuthService();
  late String _selectedRole;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _authService.register(
      username: _usernameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      role: _selectedRole,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.success,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => VerifyEmailOtpScreen(
            email: _emailController.text.trim(),
            username: _usernameController.text.trim(),
          ),
        ),
      );
    } else {
      setState(() {
        _errorMessage = response.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isChildRole = _selectedRole.toLowerCase() == 'child';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo & Header
                  Center(
                    child: ContainerBadge(
                      icon: isChildRole
                          ? Icons.child_care_rounded
                          : Icons.shield_rounded,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isChildRole
                        ? 'Đăng Ký Tài Khoản Trẻ Em'
                        : 'Đăng Ký Tài Khoản Phụ Huynh',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isChildRole
                        ? 'Tạo tài khoản để trẻ đăng nhập trên thiết bị giám sát KidGuard'
                        : 'KidGuard — Bảo vệ con bạn trong thế giới số',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Role selector
                  Center(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'Parent',
                          label: Text('Phụ Huynh'),
                          icon: Icon(Icons.person_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: 'Child',
                          label: Text('Trẻ Em'),
                          icon: Icon(Icons.child_care_rounded, size: 16),
                        ),
                      ],
                      selected: {_selectedRole},
                      onSelectionChanged: (newSelection) {
                        setState(() {
                          _selectedRole = newSelection.first;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  CustomTextField(
                    controller: _fullNameController,
                    label: isChildRole
                        ? 'Họ và tên trẻ em'
                        : 'Họ và tên phụ huynh',
                    hint: 'Ví dụ: Nguyễn Đức Chí Nguyên',
                    prefixIcon: Icons.badge_outlined,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập họ tên'
                        : null,
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: _usernameController,
                    label: 'Tên đăng nhập',
                    hint: 'Tối thiểu 3 ký tự (chữ, số, gạch dưới)',
                    prefixIcon: Icons.person_outline,
                    validator: (v) {
                      if (v == null || v.trim().length < 3) {
                        return 'Tên đăng nhập tối thiểu 3 ký tự';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(v)) {
                        return 'Chỉ chứa chữ cái, số, gạch dưới hoặc chấm';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: _emailController,
                    label: isChildRole ? 'Email trẻ em' : 'Email phụ huynh',
                    hint: 'email@example.com',
                    prefixIcon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null ||
                          !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                              .hasMatch(v)) {
                        return 'Vui lòng nhập email hợp lệ';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: _passwordController,
                    label: 'Mật khẩu',
                    hint: 'Ít nhất 6 ký tự (có chữ hoa, chữ thường, số)',
                    prefixIcon: Icons.lock_outline,
                    isPassword: true,
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'Mật khẩu phải từ 6 ký tự trở lên';
                      }
                      if (!RegExp(r'[A-Z]').hasMatch(v)) {
                        return 'Mật khẩu cần ít nhất 1 chữ in hoa';
                      }
                      if (!RegExp(r'[a-z]').hasMatch(v)) {
                        return 'Mật khẩu cần ít nhất 1 chữ in thường';
                      }
                      if (!RegExp(r'[0-9]').hasMatch(v)) {
                        return 'Mật khẩu cần ít nhất 1 chữ số';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  CustomTextField(
                    controller: _confirmPasswordController,
                    label: 'Xác nhận mật khẩu',
                    hint: 'Nhập lại mật khẩu vừa đặt',
                    prefixIcon: Icons.lock_clock_outlined,
                    isPassword: true,
                    validator: (v) {
                      if (v != _passwordController.text) {
                        return 'Mật khẩu xác nhận không khớp';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  CustomButton(
                    text: 'Đăng Ký & Nhận Mã OTP',
                    isLoading: _isLoading,
                    onPressed: _handleRegister,
                  ),
                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Đã có tài khoản? ',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Đăng nhập ngay',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
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
      ),
    );
  }
}

class ContainerBadge extends StatelessWidget {
  final IconData icon;
  const ContainerBadge({super.key, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Icon(icon, color: AppColors.primary, size: 36),
    );
  }
}
