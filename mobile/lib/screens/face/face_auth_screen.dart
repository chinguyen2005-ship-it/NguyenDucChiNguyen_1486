import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../constants/app_colors.dart';
import '../../services/face_auth_service.dart';
import '../../widgets/custom_button.dart';
import '../dashboard/admin_dashboard_screen.dart';
import '../dashboard/child_dashboard_screen.dart';
import '../dashboard/parent_dashboard_screen.dart';

enum FaceAuthMode {
  register, // Đăng ký khuôn mặt mới (cần JWT)
  login, // Đăng nhập bằng khuôn mặt
}

class FaceAuthScreen extends StatefulWidget {
  final FaceAuthMode mode;
  final String? initialUsername;

  const FaceAuthScreen({super.key, required this.mode, this.initialUsername});

  @override
  State<FaceAuthScreen> createState() => _FaceAuthScreenState();
}

class _FaceAuthScreenState extends State<FaceAuthScreen> {
  final _faceAuthService = FaceAuthService();
  final _picker = ImagePicker();
  final _usernameController = TextEditingController();

  File? _capturedImage;
  String? _base64Image;
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;
  double? _similarity;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialUsername != null && widget.initialUsername!.isNotEmpty) {
      _usernameController.text = widget.initialUsername!;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn Nguồn Ảnh Khuôn Mặt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: const Text('Chụp ảnh từ Camera'),
                subtitle: const Text('Sử dụng camera trước để chụp ảnh chân dung'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Colors.purple),
                ),
                title: const Text('Chọn ảnh từ Thư viện'),
                subtitle: const Text('Chọn ảnh khuôn mặt có sẵn trên máy'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _errorMessage = null;
      _statusMessage = null;
    });

    try {
      if (source == ImageSource.camera) {
        var status = await Permission.camera.status;
        if (!status.isGranted) {
          status = await Permission.camera.request();
          if (status.isPermanentlyDenied) {
            if (!mounted) return;
            _showPermissionDialog();
            return;
          }
          if (!status.isGranted) {
            setState(() {
              _errorMessage = 'Ứng dụng cần quyền Camera để chụp ảnh khuôn mặt.';
            });
            return;
          }
        }
      }

      final XFile? photo = await _picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 640,
        maxHeight: 640,
        imageQuality: 80,
      );

      if (photo == null) return;

      final file = File(photo.path);
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);

      setState(() {
        _capturedImage = file;
        _base64Image = base64String;
        _statusMessage =
            'Đã chọn ảnh khuôn mặt thành công. Vui lòng bấm xác nhận bên dưới.';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Không thể lấy ảnh: $e';
      });
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Quyền Camera Bị Từ Chối'),
        content: const Text(
          'Để sử dụng tính năng nhận diện khuôn mặt, bạn cần cấp quyền truy cập Camera trong Cài đặt hệ thống.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Mở Cài Đặt'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_base64Image == null) {
      setState(() {
        _errorMessage = 'Vui lòng chụp ảnh khuôn mặt trước khi tiếp tục.';
      });
      return;
    }

    if (widget.mode == FaceAuthMode.login &&
        _usernameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage =
            'Vui lòng nhập tên tài khoản của bạn để so khớp khuôn mặt.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = null;
      _similarity = null;
    });

    if (widget.mode == FaceAuthMode.register) {
      // Gọi API đăng ký khuôn mặt
      final result = await _faceAuthService.registerFace(_base64Image!);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = result.success;
        if (result.success) {
          _statusMessage = result.message;
        } else {
          _errorMessage = result.message;
        }
      });

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: AppColors.success,
          ),
        );
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } else {
      // Gọi API đăng nhập bằng khuôn mặt
      final result = await _faceAuthService.loginWithFace(
        username: _usernameController.text.trim(),
        base64Image: _base64Image!,
      );

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isSuccess = result.success;
        _similarity = result.similarity;
        if (result.success) {
          _statusMessage = result.message;
        } else {
          _errorMessage = result.message;
        }
      });

      if (result.success && result.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${result.message} (Độ khớp: ${((result.similarity ?? 1.0) * 100).toStringAsFixed(1)}%)',
            ),
            backgroundColor: AppColors.success,
          ),
        );

        // Điều hướng vào đúng Dashboard theo vai trò
        Widget destination;
        final primaryRole = result.user!.primaryRole.toLowerCase();
        if (primaryRole == 'admin') {
          destination = AdminDashboardScreen(user: result.user!);
        } else if (primaryRole == 'child') {
          destination = ChildDashboardScreen(user: result.user!);
        } else {
          destination = ParentDashboardScreen(user: result.user!);
        }

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => destination),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = widget.mode == FaceAuthMode.register;
    final title = isRegister ? 'Đăng Ký Khuôn Mặt' : 'Đăng Nhập Khuôn Mặt';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Banner
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.face_retouching_natural_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRegister
                                  ? 'Bảo Mật Sinh Trắc Học'
                                  : 'Nhận Diện AI Khuôn Mặt',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isRegister
                                  ? 'Đăng ký khuôn mặt để đăng nhập nhanh chóng bằng camera mà không cần gõ mật khẩu.'
                                  : 'Nhìn thẳng vào camera trong điều kiện đủ sáng để hệ thống so khớp đặc trưng ArcFace.',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Username field (only in Login mode)
              if (!isRegister) ...[
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Tên tài khoản (Username) *',
                    hintText: 'Nhập username của bạn',
                    prefixIcon: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Camera viewfinder / Image preview area
              Center(
                child: GestureDetector(
                  onTap: _isLoading ? null : _showImageSourceDialog,
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isSuccess
                            ? AppColors.success
                            : (_capturedImage != null
                                  ? AppColors.primary
                                  : AppColors.border),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _capturedImage != null
                          ? Image.file(
                              _capturedImage!,
                              width: 240,
                              height: 240,
                              fit: BoxFit.cover,
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_alt_rounded,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Chạm để chụp hoặc chọn ảnh',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Camera / Thư viện',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons to re-capture
              Center(
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _showImageSourceDialog,
                  icon: Icon(
                    _capturedImage != null
                        ? Icons.replay_rounded
                        : Icons.photo_camera_back_outlined,
                  ),
                  label: Text(
                    _capturedImage != null
                        ? 'Chụp hoặc chọn ảnh khác'
                        : 'Mở Camera / Chọn Ảnh',
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status / Feedback Card
              if (_similarity != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _isSuccess
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isSuccess
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSuccess
                            ? Icons.check_circle_rounded
                            : Icons.highlight_off_rounded,
                        color: _isSuccess ? AppColors.success : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Độ tương đồng ArcFace: ${(_similarity! * 100).toStringAsFixed(1)}% (Ngưỡng 42.0%)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _isSuccess
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_statusMessage != null && _errorMessage == null) ...[
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
                        Icons.check_circle_outline_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Confirm Button
              CustomButton(
                text: isRegister
                    ? 'Xác Nhận Đăng Ký Khuôn Mặt'
                    : 'Xác Thực & Đăng Nhập',
                isLoading: _isLoading,
                icon: isRegister
                    ? Icons.verified_user_rounded
                    : Icons.login_rounded,
                onPressed: _capturedImage == null ? null : _handleSubmit,
              ),
              const SizedBox(height: 16),

              // Instructions Card
              Card(
                elevation: 0,
                color: Colors.blue.shade50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Colors.blue,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Lưu ý khi chụp ảnh khuôn mặt:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Đặt khuôn mặt ở giữa khung hình, nhìn thẳng.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                      Text(
                        '• Đảm bảo ánh sáng rõ ràng, không bị chói hoặc quá tối.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                      Text(
                        '• Không đeo khẩu trang hoặc kính râm che mắt.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                      Text(
                        '• Khung hình chỉ được có DUY NHẤT một khuôn mặt.',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
