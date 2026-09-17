import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';
import '../services/cloud_sync_service.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;

  User? _currentUser;
  String? _coverImagePath;
  String? _profileImagePath;
  String? _lastSyncDate;

  bool _isLoadingDoc = true;
  bool _isSavingProfile = false;
  bool _isSavingCover = false;
  bool _isSavingName = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _nameController = TextEditingController(text: _currentUser?.displayName ?? '');
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoadingDoc = true);

    try {
      final uid = _currentUser?.uid;
      if (uid != null && uid.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final localProfile = prefs.getString('local_profile_image_$uid');
        final localCover = prefs.getString('local_cover_image_$uid');

        if (mounted) {
          setState(() {
            _profileImagePath = localProfile;
            _coverImagePath = localCover;
          });
        }

        // Fetch display name from Firestore if empty locally
        if (_nameController.text.trim().isEmpty) {
          final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          if (doc.exists && mounted) {
            final data = doc.data();
            if (data != null && data['display_name'] != null) {
              _nameController.text = data['display_name'] as String;
            }
          }
        }
      }

      final lastSync = await CloudSyncService().getLastSyncDate();
      if (mounted) {
        setState(() {
          _lastSyncDate = lastSync;
          _isLoadingDoc = false;
        });
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] Error loading user images: $e');
      if (mounted) setState(() => _isLoadingDoc = false);
    }
  }

  /// Pick and save Profile Picture to local device storage
  Future<void> _pickAndSaveProfileImage() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isSavingProfile = true);

      final Uint8List bytes = await pickedFile.readAsBytes();
      final prefs = await SharedPreferences.getInstance();
      String savedPath;

      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        final localFile = File('${directory.path}/profile_pic_$uid.jpg');
        await localFile.writeAsBytes(bytes, flush: true);
        savedPath = localFile.path;
      } else {
        savedPath = base64Encode(bytes);
      }

      await prefs.setString('local_profile_image_$uid', savedPath);

      if (mounted) {
        setState(() {
          _profileImagePath = savedPath;
          _isSavingProfile = false;
        });
        _showSnack('تم حفظ الصورة الشخصية على الجهاز بنجاح 📸', isSuccess: true);
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] Profile save error: $e');
      if (mounted) {
        setState(() => _isSavingProfile = false);
        _showSnack('تعذر حفظ الصورة الشخصية: $e', isSuccess: false);
      }
    }
  }

  /// Pick and save Cover Image to local device storage
  Future<void> _pickAndSaveCoverImage() async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => _isSavingCover = true);

      final Uint8List bytes = await pickedFile.readAsBytes();
      final prefs = await SharedPreferences.getInstance();
      String savedPath;

      if (!kIsWeb) {
        final directory = await getApplicationDocumentsDirectory();
        final localFile = File('${directory.path}/cover_pic_$uid.jpg');
        await localFile.writeAsBytes(bytes, flush: true);
        savedPath = localFile.path;
      } else {
        savedPath = base64Encode(bytes);
      }

      await prefs.setString('local_cover_image_$uid', savedPath);

      if (mounted) {
        setState(() {
          _coverImagePath = savedPath;
          _isSavingCover = false;
        });
        _showSnack('تم حفظ صورة الغلاف على الجهاز بنجاح 🖼️', isSuccess: true);
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] Cover save error: $e');
      if (mounted) {
        setState(() => _isSavingCover = false);
        _showSnack('تعذر حفظ صورة الغلاف: $e', isSuccess: false);
      }
    }
  }

  /// Update Display Name
  Future<void> _saveDisplayName() async {
    if (!_formKey.currentState!.validate()) return;

    final newName = _nameController.text.trim();
    final uid = _currentUser?.uid;
    if (uid == null) return;

    setState(() => _isSavingName = true);

    try {
      await _currentUser?.updateDisplayName(newName);
      await _currentUser?.reload();
      _currentUser = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'display_name': newName,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        setState(() => _isSavingName = false);
        _showSnack('تم حفظ الاسم بنجاح ✅', isSuccess: true);
      }
    } catch (e) {
      debugPrint('[UserProfileScreen] Save display name error: $e');
      if (mounted) {
        setState(() => _isSavingName = false);
        _showSnack('تعذر تحديث الاسم: $e', isSuccess: false);
      }
    }
  }

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

  ImageProvider? get _profileImageProvider => _getImageProvider(_profileImagePath);
  ImageProvider? get _coverImageProvider => _getImageProvider(_coverImagePath);

  void _showSnack(String message, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? AppColors.income : AppColors.expense,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: const Text(
          'الملف الشخصي',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: _isLoadingDoc ? null : _loadUserData,
          ),
        ],
      ),
      body: _isLoadingDoc
          ? const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal))
          : SingleChildScrollView(
              child: Column(
                children: [
                  // ── Header: Cover Image & Avatar Stack ─────────────────────
                  _buildHeaderStack(isDark, size),

                  const SizedBox(height: 55),

                  // ── Form & Profile Details ─────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileForm(isDark),
                          const SizedBox(height: 24),
                          _buildAccountInfoCard(isDark),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header with Cover & CircleAvatar Stack
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeaderStack(bool isDark, Size size) {
    const double coverHeight = 190.0;
    const double avatarRadius = 56.0;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 1. Cover Image Container
        Container(
          width: double.infinity,
          height: coverHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F766E), Color(0xFF14B8A6), Color(0xFF0284C7)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_coverImageProvider != null)
                Image(
                  image: _coverImageProvider!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_rounded, color: Colors.white70, size: 40),
                  ),
                ),
              // Subtle gradient overlay for readability
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
              // Loading spinner during cover saving
              if (_isSavingCover)
                Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              // Edit Cover Button
              Positioned(
                bottom: 12,
                left: 16,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _isSavingCover ? null : _pickAndSaveCoverImage,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _coverImagePath != null ? 'تغيير الغلاف' : 'إضافة غلاف',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Overlapping Profile Picture Avatar
        Positioned(
          bottom: -(avatarRadius),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: isDark ? AppColors.darkCard : const Color(0xFFE2E8F0),
                  backgroundImage: _profileImageProvider,
                  child: _profileImageProvider == null
                      ? Icon(
                          Icons.person_rounded,
                          size: 60,
                          color: isDark ? AppColors.darkTextSecondary : const Color(0xFF64748B),
                        )
                      : null,
                ),
              ),
              // Loading spinner during profile saving
              if (_isSavingProfile)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    ),
                  ),
                ),
              // Camera Badge Button on Avatar
              Positioned(
                bottom: 2,
                right: 2,
                child: Material(
                  color: AppColors.primaryTeal,
                  shape: const CircleBorder(),
                  elevation: 3,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _isSavingProfile ? null : _pickAndSaveProfileImage,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Profile Form (Display Name & Email)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProfileForm(bool isDark) {
    final email = _currentUser?.email ?? 'غير محدد';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note_rounded, color: AppColors.primaryTeal, size: 22),
                const SizedBox(width: 8),
                Text(
                  'بيانات الحساب',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Display Name Input
            TextFormField(
              controller: _nameController,
              enabled: !_isSavingName,
              decoration: InputDecoration(
                labelText: 'الاسم المعروض (Display Name)',
                hintText: 'أدخل اسمك...',
                prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primaryTeal),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primaryTeal, width: 2),
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'يرجى إدخال اسمك المعروض';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Read-only Email Field
            TextFormField(
              initialValue: email,
              readOnly: true,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                prefixIcon: const Icon(Icons.email_outlined, color: Colors.grey),
                suffixIcon: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.verified_rounded, color: AppColors.income, size: 18),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.5)
                    : const Color(0xFFF1F5F9),
              ),
            ),

            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSavingName ? null : _saveDisplayName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primaryTeal.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _isSavingName
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(
                  _isSavingName ? 'جاري الحفظ...' : 'حفظ التغييرات',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Account Information & Cloud Sync Card
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAccountInfoCard(bool isDark) {
    final uid = _currentUser?.uid ?? '—';
    final shortUid = uid.length > 12 ? '${uid.substring(0, 10)}...' : uid;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_sync_rounded, color: AppColors.primaryTealLight, size: 22),
              const SizedBox(width: 8),
              Text(
                'حالة المزامنة السحابية',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(
            icon: Icons.fingerprint_rounded,
            title: 'معرف المستخدم (UID)',
            value: shortUid,
            isDark: isDark,
            trailing: IconButton(
              icon: const Icon(Icons.copy_rounded, size: 16),
              tooltip: 'نسخ المعرف',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: uid));
                _showSnack('تم نسخ معرف الحساب', isSuccess: true);
              },
            ),
          ),
          const Divider(height: 16),
          _infoRow(
            icon: Icons.cloud_done_rounded,
            title: 'المزامنة السحابية اللحظية',
            value: 'مفعلة وتعمل تلقائياً',
            valueColor: AppColors.income,
            isDark: isDark,
          ),
          const Divider(height: 16),
          _infoRow(
            icon: Icons.history_rounded,
            title: 'آخر مزامنة مكتملة',
            value: _lastSyncDate ?? 'غير متوفرة حالياً',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String title,
    required String value,
    Color? valueColor,
    required bool isDark,
    Widget? trailing,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
