import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/debt_provider.dart';
import '../../providers/category_provider.dart';
import '../../services/cloud_sync_service.dart';
import '../main_navigation_screen.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isSyncingCloud = false;
  String _syncLoadingText = 'جاري مزامنة بياناتك لحسابك، الرجاء الانتظار...';

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _setLoading(bool val) => setState(() => _isLoading = val);

  /// Navigate to the main app and clear the navigation stack.
  void _goToMainApp() {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      (route) => false,
    );
  }

  /// Download user cloud data into local SQLite, refresh in-memory state, and navigate
  Future<void> _syncAndNavigate(User? user) async {
    setState(() {
      _isLoading = false;
      _isSyncingCloud = true;
      _syncLoadingText = 'جاري مزامنة بياناتك لحسابك، الرجاء الانتظار...';
    });

    try {
      if (user != null) {
        debugPrint('[LoginScreen] Downloading cloud data for user: ${user.uid}');
        final syncResult = await CloudSyncService().downloadCloudDataToLocal(user.uid);
        debugPrint('[LoginScreen] Cloud download result: ${syncResult.success} - ${syncResult.message}');

        // Refresh providers so restored data appears in memory
        if (!mounted) return;
        try {
          final finProvider = Provider.of<FinanceProvider>(context, listen: false);
          final debtProvider = Provider.of<DebtProvider>(context, listen: false);
          final catProvider = Provider.of<CategoryProvider>(context, listen: false);

          await finProvider.loadAllData();
          await debtProvider.loadAll();
          await catProvider.loadCategories();
        } catch (e) {
          debugPrint('[LoginScreen] Provider reload error: $e');
        }
      }
    } catch (e) {
      debugPrint('[LoginScreen] Error during initial login sync: $e');
    } finally {
      if (mounted) {
        setState(() => _isSyncingCloud = false);
        _goToMainApp();
      }
    }
  }

  /// Sign in with Email & Password
  Future<void> _submitLogin() async {
    if (!_formKey.currentState!.validate()) return;
    _setLoading(true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    _setLoading(false);
    if (!mounted) return;

    if (success) {
      _showSnack('مرحباً بك! تم تسجيل الدخول بنجاح', isSuccess: true);
      final user = FirebaseAuth.instance.currentUser;
      await _syncAndNavigate(user);
    } else {
      _showSnack(authProvider.errorMessage ?? 'فشل تسجيل الدخول', isSuccess: false);
    }
  }

  /// Sign in with Google
  Future<void> _signInWithGoogle() async {
    _setLoading(true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.signInWithGoogle();

    _setLoading(false);
    if (!mounted) return;

    if (success) {
      _showSnack('تم تسجيل الدخول بـ Google بنجاح', isSuccess: true);
      final user = FirebaseAuth.instance.currentUser;
      await _syncAndNavigate(user);
    } else {
      final msg = authProvider.errorMessage ?? 'فشل تسجيل الدخول عبر Google';
      // Only show error if user didn't just cancel
      if (!msg.contains('إلغاء')) {
        _showSnack(msg, isSuccess: false);
      }
    }
  }

  /// Activates local-only guest mode — zero Firebase calls.
  Future<void> _continueAsGuest() async {
    _setLoading(true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.enterGuestMode();
    _setLoading(false);
    _goToMainApp();
  }

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
      body: Stack(
        children: [
          // ── Decorative background blobs ─────────────────────────────────
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryTeal.withValues(alpha: isDark ? 0.18 : 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primaryTealLight.withValues(alpha: isDark ? 0.14 : 0.09),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main scrollable content ─────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width > 600 ? 80 : 24,
                      vertical: 24,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Header ──────────────────────────────────────
                          _buildHeader(isDark),

                          const SizedBox(height: 36),

                          // ── Email / Password Form ────────────────────────
                          _buildEmailForm(isDark),

                          const SizedBox(height: 28),

                          // ── Login Button ────────────────────────────────
                          _buildLoginButton(),

                          const SizedBox(height: 20),

                          // ── Sign-up link ────────────────────────────────
                          _buildSignUpRow(isDark),

                          const SizedBox(height: 24),

                          // ── Divider "أو" ─────────────────────────────────
                          _buildDivider(isDark),

                          const SizedBox(height: 24),

                          // ── Google Button ───────────────────────────────
                          _buildGoogleButton(isDark),

                          const SizedBox(height: 32),

                          // ── Guest Mode ──────────────────────────────────
                          _buildGuestSection(isDark),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Full-screen sync / loading overlay ───────────────────────────
          if (_isSyncingCloud)
            Container(
              color: Colors.black.withValues(alpha: 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.cloud_sync_rounded,
                            color: AppColors.primaryTeal,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _syncLoadingText,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          color: AppColors.primaryTeal,
                          strokeWidth: 3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primaryTeal),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Header
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        // App icon with gradient
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryTeal.withValues(alpha: 0.38),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            color: Colors.white,
            size: 46,
          ),
        ),

        const SizedBox(height: 22),

        // App name
        Text(
          'ميزانيتي',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            letterSpacing: 0.3,
          ),
        ),

        const SizedBox(height: 8),

        // Subtitle
        Text(
          'تسجيل الدخول إلى حسابك على تطبيق ميزانيتي',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.55,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Email / Password Form
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEmailForm(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
            enabled: !_isLoading,
            decoration: _inputDecoration(
              isDark: isDark,
              label: 'البريد الإلكتروني',
              hint: 'example@email.com',
              icon: Icons.email_outlined,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'يرجى إدخال البريد الإلكتروني';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                return 'صيغة البريد الإلكتروني غير صحيحة';
              }
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Password
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_isLoading,
            decoration: _inputDecoration(
              isDark: isDark,
              label: 'كلمة المرور',
              icon: Icons.lock_outline_rounded,
            ).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'يرجى إدخال كلمة المرور';
              if (val.length < 6) return 'يجب ألا تقل كلمة المرور عن 6 خانات';
              return null;
            },
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required bool isDark,
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.primaryTeal, size: 20),
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
      fillColor: isDark ? AppColors.darkCard : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Login Button
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoginButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _submitLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryTeal,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryTeal.withValues(alpha: 0.55),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: const Text(
          'تسجيل الدخول',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sign-up Link Row
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSignUpRow(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ليس لديك حساب؟',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  );
                },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            'إنشاء حساب جديد',
            style: TextStyle(
              color: AppColors.primaryTeal,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Divider "أو"
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildDivider(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'أو',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Google Button
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGoogleButton(bool isDark) {
    return SizedBox(
      height: 54,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          side: BorderSide(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google "G" logo drawn with CustomPaint
            const _GoogleLogo(size: 22),
            const SizedBox(width: 12),
            const Text(
              'المتابعة باستخدام Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Guest Mode Section
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildGuestSection(bool isDark) {
    return Column(
      children: [
        // Dashed separator
        Row(
          children: [
            Expanded(
              child: Divider(
                color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                    .withValues(alpha: 0.6),
                thickness: 1,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'بدون حساب',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: (isDark ? AppColors.darkBorder : AppColors.lightBorder)
                    .withValues(alpha: 0.6),
                thickness: 1,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Guest mode card
        GestureDetector(
          onTap: _isLoading ? null : _continueAsGuest,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? AppColors.darkBorder.withValues(alpha: 0.6)
                    : AppColors.lightBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBorder.withValues(alpha: 0.4)
                        : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_outline_rounded,
                    color: isDark ? AppColors.darkTextSecondary : const Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الدخول كضيف (بدون إنترنت)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'بياناتك محفوظة محلياً على هذا الجهاز فقط',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Google Logo Widget (drawn via Canvas — no external asset needed)
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.width;
    final double cx = s / 2;
    final double cy = s / 2;
    final double r = s / 2;

    // Background circle (white)
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white,
    );

    // We draw a simplified Google "G" shape using 4 arcs (colored quadrants)
    // Blue segment (top-right)
    _drawSegment(canvas, cx, cy, r * 0.8, 270, 60, const Color(0xFF4285F4));
    // Red segment (top-left)
    _drawSegment(canvas, cx, cy, r * 0.8, 150, 120, const Color(0xFFEA4335));
    // Yellow segment (bottom-left)
    _drawSegment(canvas, cx, cy, r * 0.8, 210, 60, const Color(0xFFFBBC05));
    // Green segment (bottom-right)
    _drawSegment(canvas, cx, cy, r * 0.8, 330, 60, const Color(0xFF34A853));

    // White center to create ring effect
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.48,
      Paint()..color = Colors.white,
    );

    // The horizontal "shelf" of the G in the right half
    final rRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx, cy - r * 0.13, r * 0.82, r * 0.26),
      const Radius.circular(4),
    );
    canvas.drawRRect(rRect, Paint()..color = const Color(0xFF4285F4));
  }

  void _drawSegment(
    Canvas canvas,
    double cx,
    double cy,
    double r,
    double startDeg,
    double sweepDeg,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(cx, cy)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, cy), radius: r),
        startDeg * (3.14159265 / 180),
        sweepDeg * (3.14159265 / 180),
        false,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
