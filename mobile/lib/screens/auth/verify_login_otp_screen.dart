import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/auth_models.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/otp_input_fields.dart';
import '../dashboard/admin_dashboard_screen.dart';
import '../dashboard/child_dashboard_screen.dart';
import '../dashboard/parent_dashboard_screen.dart';

class VerifyLoginOtpScreen extends StatefulWidget {
  final String username;
  final String? email;

  const VerifyLoginOtpScreen({super.key, required this.username, this.email});

  @override
  State<VerifyLoginOtpScreen> createState() => _VerifyLoginOtpScreenState();
}

class _VerifyLoginOtpScreenState extends State<VerifyLoginOtpScreen> {
  final _authService = AuthService();
  String _enteredOtp = '';
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _successMessage;

  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() {
      _resendCountdown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() {
          _resendCountdown--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    if (_enteredOtp.length != 6) {
      setState(() {
        _errorMessage = 'Vui lòng nhập đủ 6 chữ số mã OTP.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final response = await _authService.verifyOtp(
      username: widget.username,
      otpCode: _enteredOtp,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (response.success && response.user != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.success,
        ),
      );

      _navigateByRole(response.user!);
    } else {
      setState(() {
        _errorMessage = response.message;
      });
    }
  }

  void _navigateByRole(UserProfile user) {
    Widget destination;
    if (user.isAdmin) {
      destination = AdminDashboardScreen(user: user);
    } else if (user.isChild) {
      destination = ChildDashboardScreen(user: user);
    } else {
      destination = ParentDashboardScreen(user: user);
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _isResending) return;
    final targetEmail = (widget.email != null && widget.email!.isNotEmpty)
        ? widget.email!
        : (widget.username.contains('@') ? widget.username : null);

    if (targetEmail == null || targetEmail.isEmpty) {
      setState(() {
        _errorMessage = 'Không xác định được email để gửi lại mã.';
      });
      return;
    }

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final response = await _authService.resendOtp(
      email: targetEmail,
      purpose: 2, // Login
    );

    setState(() {
      _isResending = false;
    });

    if (!mounted) return;

    if (response.success) {
      _startTimer();
      setState(() {
        _successMessage = response.message;
      });
    } else {
      setState(() {
        _errorMessage = response.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Xác Thực Đăng Nhập 2FA'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: AppColors.primary,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Bảo Mật Hai Lớp (2FA)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Mã OTP xác thực đăng nhập 6 chữ số đã được gửi tới email của tài khoản [${widget.username}].',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

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

              if (_successMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              OtpInputFields(
                length: 6,
                onChanged: (val) => _enteredOtp = val,
                onCompleted: (val) {
                  _enteredOtp = val;
                  _handleVerify();
                },
              ),
              const SizedBox(height: 24),

              CustomButton(
                text: 'Xác Thực & Đăng Nhập',
                isLoading: _isLoading,
                onPressed: _handleVerify,
              ),
              const SizedBox(height: 24),

              if (widget.email != null && widget.email!.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Chưa nhận được mã? ',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    _resendCountdown > 0
                        ? Text(
                            'Gửi lại sau ($_resendCountdown s)',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : GestureDetector(
                            onTap: _isResending ? null : _handleResendOtp,
                            child: Text(
                              _isResending ? 'Đang gửi...' : 'Gửi lại OTP',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
