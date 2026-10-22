import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../models/admin_user_model.dart';
import '../../models/auth_models.dart';
import '../../services/admin_service.dart';

class AdminUserManagementScreen extends StatefulWidget {
  final UserProfile currentUser;
  final AdminService? adminService;

  const AdminUserManagementScreen({
    super.key,
    required this.currentUser,
    this.adminService,
  });

  @override
  State<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState extends State<AdminUserManagementScreen> {
  late final AdminService _adminService;
  final _searchController = TextEditingController();

  List<AdminUserModel> _users = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _adminService = widget.adminService ?? AdminService();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers({String? search}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final res = await _adminService.getUsers(search: search);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res.success && res.data != null) {
        _users = res.data!;
      } else {
        _errorMessage = res.message;
      }
    });
  }

  Future<void> _showChangeRoleDialog(AdminUserModel user) async {
    if (user.username.toLowerCase() ==
            widget.currentUser.username.toLowerCase() &&
        user.isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn không thể tự hạ quyền Admin của chính mình!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String selectedRole = user.primaryRole;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Đổi Vai Trò: @${user.username}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn vai trò mới cho tài khoản. Sau khi đổi, người dùng cần đăng nhập lại:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              RadioGroup<String>(
                groupValue: selectedRole,
                onChanged: (val) =>
                    setDialogState(() => selectedRole = val ?? selectedRole),
                child: Column(
                  children: const [
                    RadioListTile<String>(
                      title: Text('Child (Trẻ em)'),
                      subtitle: Text(
                        'Có thể gán vào thiết bị giám sát KidGuard',
                      ),
                      value: 'Child',
                    ),
                    RadioListTile<String>(
                      title: Text('Parent (Phụ huynh)'),
                      subtitle: Text(
                        'Quản lý thiết bị con và cấu hình an toàn',
                      ),
                      value: 'Parent',
                    ),
                    RadioListTile<String>(
                      title: Text('Admin (Quản trị viên)'),
                      subtitle: Text('Toàn quyền quản lý hệ thống'),
                      value: 'Admin',
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Cập Nhật'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedRole != user.primaryRole) {
      final res = await _adminService.setUserRole(user.username, selectedRole);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.message),
          backgroundColor: res.success ? AppColors.success : AppColors.error,
        ),
      );

      if (res.success) {
        _loadUsers(search: _searchController.text.trim());
      }
    }
  }

  Future<void> _handleUnlock(AdminUserModel user) async {
    final res = await _adminService.unlockUser(user.username);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res.message),
        backgroundColor: res.success ? AppColors.success : AppColors.error,
      ),
    );

    if (res.success) {
      _loadUsers(search: _searchController.text.trim());
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'parent':
        return AppColors.primary;
      case 'child':
        return AppColors.secondary;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản Lý Phân Quyền Người Dùng'),
        backgroundColor: Colors.purple.shade800,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search & Guide Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên tài khoản hoặc email...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _loadUsers();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (val) => _loadUsers(search: val.trim()),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.purple),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cấp quyền Child cho tài khoản để Phụ huynh có thể gán vào thiết bị giám sát KidGuard.',
                          style: TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 48,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.error),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => _loadUsers(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _users.isEmpty
                ? const Center(
                    child: Text(
                      'Không tìm thấy người dùng nào',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () =>
                        _loadUsers(search: _searchController.text.trim()),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _users.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (ctx, idx) {
                        final u = _users[idx];
                        final roleColor = _getRoleColor(u.primaryRole);

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: roleColor.withValues(
                                        alpha: 0.15,
                                      ),
                                      child: Icon(
                                        u.isChild
                                            ? Icons.child_care_rounded
                                            : u.isAdmin
                                            ? Icons.admin_panel_settings_rounded
                                            : Icons.person_rounded,
                                        color: roleColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  u.username,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: roleColor.withValues(
                                                    alpha: 0.15,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  u.primaryRole,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: roleColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            u.email ?? 'Chưa có email',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Status tags
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: u.emailConfirmed
                                            ? Colors.green.shade50
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: u.emailConfirmed
                                              ? Colors.green.shade200
                                              : Colors.orange.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            u.emailConfirmed
                                                ? Icons.check_circle
                                                : Icons.warning_amber_rounded,
                                            size: 13,
                                            color: u.emailConfirmed
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            u.emailConfirmed
                                                ? 'Đã xác minh email'
                                                : 'Chưa xác minh email',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: u.emailConfirmed
                                                  ? Colors.green.shade800
                                                  : Colors.orange.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (u.hasFace)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.deepPurple.shade200,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.face_rounded,
                                              size: 13,
                                              color: Colors.deepPurple,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Có Face AI',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.deepPurple,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (u.isLockedOut)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.red.shade200,
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.lock_clock,
                                              size: 13,
                                              color: Colors.red,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'Bị khóa đăng nhập',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                // Action buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (u.isLockedOut)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 8,
                                        ),
                                        child: OutlinedButton.icon(
                                          onPressed: () => _handleUnlock(u),
                                          icon: const Icon(
                                            Icons.lock_open,
                                            size: 16,
                                          ),
                                          label: const Text('Mở Khóa'),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                Colors.green.shade800,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ElevatedButton.icon(
                                      onPressed: () => _showChangeRoleDialog(u),
                                      icon: const Icon(
                                        Icons.manage_accounts_rounded,
                                        size: 16,
                                      ),
                                      label: const Text('Đổi Vai Trò'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.purple.shade700,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
