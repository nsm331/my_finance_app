import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/guest_service.dart';
import '../services/auth_service.dart';
import '../core/constants/app_colors.dart';
import '../screens/settings_screen.dart';
import '../screens/wallets_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/user_profile_screen.dart';

/// A modern RTL-compatible Navigation Drawer for "ميزانيتي".
/// Adapts its header and actions based on whether the user is a Guest or
/// a signed-in Firebase user.
class CustomDrawer extends StatefulWidget {
  final VoidCallback? onNavigateToDashboard;
  final VoidCallback? onNavigateToWallets;

  const CustomDrawer({
    super.key,
    this.onNavigateToDashboard,
    this.onNavigateToWallets,
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  bool _isGuest = false;
  bool _isLoading = true;
  String? _localProfileImagePath;

  @override
  void initState() {
    super.initState();
    _loadUserState();
  }

  Future<void> _loadUserState() async {
    final guest = await GuestService.isGuestMode();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    String? localImg;
    if (uid != null && uid.isNotEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        localImg = prefs.getString('local_profile_image_$uid');
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isGuest = guest;
        _localProfileImagePath = localImg;
        _isLoading = false;
      });
    }
  }

  void _closeAndNavigate(VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  Future<void> _handleLogout() async {
    Navigator.pop(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              _isGuest ? Icons.person_off_rounded : Icons.logout_rounded,
              color: AppColors.expense,
            ),
            const SizedBox(width: 8),
            Text(
              _isGuest ? 'الخروج من وضع الضيف' : 'تسجيل الخروج',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          _isGuest
              ? 'هل تريد الخروج من وضع الضيف والعودة إلى شاشة تسجيل الدخول؟'
              : 'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'إلغاء',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expense,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    if (_isGuest) {
      await GuestService.exitGuestMode();
    } else {
      final authService = AuthService();
      await authService.signOut();
    }

    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Widget _buildHeader(bool isDark) {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (_isGuest) {
      return _GuestDrawerHeader(isDark: isDark);
    }
    return _FirebaseDrawerHeader(
      user: firebaseUser,
      isDark: isDark,
      localImagePath: _localProfileImagePath,
      onTap: () async {
        Navigator.pop(context);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UserProfileScreen()),
        );
        _loadUserState();
      },
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    required VoidCallback onTap,
    bool isDark = false,
  }) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: isDark ? 0.18 : 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      horizontalTitleGap: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.82,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          bottomLeft: Radius.circular(24),
        ),
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  _buildHeader(isDark),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      children: [
                        _buildTile(
                          icon: Icons.dashboard_rounded,
                          title: 'الرئيسية',
                          iconColor: AppColors.primaryTeal,
                          isDark: isDark,
                          onTap: () => _closeAndNavigate(() {
                            widget.onNavigateToDashboard?.call();
                          }),
                        ),
                        const SizedBox(height: 4),
                        _buildTile(
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'المحافظ والحسابات',
                          iconColor: AppColors.usdColor,
                          isDark: isDark,
                          onTap: () => _closeAndNavigate(() {
                            if (widget.onNavigateToWallets != null) {
                              widget.onNavigateToWallets!();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const WalletsScreen(isEmbedded: false),
                                ),
                              );
                            }
                          }),
                        ),
                        const SizedBox(height: 4),
                        _buildTile(
                          icon: Icons.settings_rounded,
                          title: 'الإعدادات',
                          iconColor: AppColors.sarColor,
                          isDark: isDark,
                          onTap: () => _closeAndNavigate(() {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 4),
                        _buildTile(
                          icon: Icons.backup_rounded,
                          title: 'النسخ الاحتياطي',
                          iconColor: const Color(0xFF8B5CF6),
                          isDark: isDark,
                          onTap: () => _closeAndNavigate(() {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 12),
                        Divider(
                          color: isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder,
                          thickness: 1,
                          indent: 4,
                          endIndent: 4,
                        ),
                        const SizedBox(height: 8),
                        _buildTile(
                          icon: _isGuest
                              ? Icons.person_off_rounded
                              : Icons.logout_rounded,
                          title: _isGuest
                              ? 'الخروج من وضع الضيف'
                              : 'تسجيل الخروج',
                          iconColor: AppColors.expense,
                          isDark: isDark,
                          onTap: _handleLogout,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16, top: 8),
                    child: Text(
                      'ميزانيتي — تطبيقك المالي الشخصي',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─── Firebase User Header ────────────────────────────────────────────────────

class _FirebaseDrawerHeader extends StatelessWidget {
  final User? user;
  final bool isDark;
  final String? localImagePath;
  final VoidCallback? onTap;

  const _FirebaseDrawerHeader({
    required this.user,
    required this.isDark,
    this.localImagePath,
    this.onTap,
  });

  ImageProvider? _getImageProvider(String? path) {
    if (path == null || path.isEmpty) return null;
    if (!kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } else {
      try {
        final clean = path.contains(',') ? path.split(',').last : path;
        return MemoryImage(base64Decode(clean));
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        (user?.displayName?.isNotEmpty == true) ? user!.displayName! : 'مستخدم ميزانيتي';
    final email = user?.email ?? '';
    final photoUrl = user?.photoURL;
    final imageProvider = _getImageProvider(localImagePath) ??
        (photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
        ),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          backgroundImage: imageProvider,
                          child: imageProvider == null
                              ? const Icon(Icons.person_rounded,
                                  color: Colors.white, size: 32)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.income,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 10),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_outlined, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'تعديل',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_done_rounded,
                        color: Colors.white, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      'حساب مسجل — مزامنة سحابية مفعلة',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Guest Mode Header ───────────────────────────────────────────────────────

class _GuestDrawerHeader extends StatelessWidget {
  final bool isDark;
  const _GuestDrawerHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF334155)]
              : [const Color(0xFF475569), const Color(0xFF64748B)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.4),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'وضع الضيف',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'مزامنة سحابية غير مفعلة',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: Colors.white70, size: 13),
                const SizedBox(width: 5),
                Text(
                  'وضع غير متصل — بيانات محلية فقط',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
