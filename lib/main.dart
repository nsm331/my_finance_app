import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_theme.dart';
import 'providers/theme_provider.dart';
import 'providers/security_provider.dart';
import 'providers/category_provider.dart';
import 'providers/finance_provider.dart';
import 'providers/debt_provider.dart';
import 'providers/auth_provider.dart';
import 'services/hive_db_service.dart';
import 'services/data_migration_service.dart';
import 'services/backup_service.dart';
import 'services/firebase_service.dart';
import 'services/auto_sync_service.dart';
import 'services/guest_service.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dbService = HiveDbService();
  try {
    await dbService.init();
    await FirebaseService.initialize();
    AutoSyncService.instance.initialize();
    final migrationService = DataMigrationService();
    await migrationService.migrateHiveToSqlite(hiveDbService: dbService);
    final backupService = BackupService();
    await backupService.checkAndRunDailyBackup();
  } catch (e, stack) {
    debugPrint('[main] Startup initialization error: $e\n$stack');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(dbService: dbService)),
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => CategoryProvider()),
        ChangeNotifierProvider(create: (_) => FinanceProvider()),
        ChangeNotifierProvider(create: (_) => DebtProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyFinanceApp(),
    ),
  );
}

class MyFinanceApp extends StatelessWidget {
  const MyFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'ميزانيتي',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      home: FutureBuilder<bool>(
        future: GuestService.isGuestMode(),
        builder: (context, guestSnapshot) {
          if (guestSnapshot.connectionState != ConnectionState.done) {
            return const _SplashLoadingScreen();
          }

          final isGuest = guestSnapshot.data ?? false;

          // Guest Mode: bypass Firebase entirely
          if (isGuest) {
            return const MainNavigationScreen();
          }

          // Firebase not initialized: go to login
          if (!FirebaseService.isInitialized) {
            return const LoginScreen();
          }

          // Normal Mode: listen to Firebase Auth state changes
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, authSnapshot) {
              if (authSnapshot.connectionState == ConnectionState.waiting) {
                return const _SplashLoadingScreen();
              }
              if (authSnapshot.hasData && authSnapshot.data != null) {
                return const MainNavigationScreen();
              }
              return const LoginScreen();
            },
          );
        },
      ),
    );
  }
}

class _SplashLoadingScreen extends StatelessWidget {
  const _SplashLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF8FAFC),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D9488).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'ميزانيتي',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: Color(0xFF0D9488),
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
