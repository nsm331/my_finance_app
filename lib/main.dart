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
import 'screens/main_navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services safely before runApp
  final dbService = HiveDbService();
  try {
    await dbService.init();

    // Safely initialize Firebase
    await FirebaseService.initialize();

    // One-time safe migration from Hive to SQLite
    final migrationService = DataMigrationService();
    await migrationService.migrateHiveToSqlite(hiveDbService: dbService);

    // Perform daily auto-backup check
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

      // Arabic Only & Mandatory RTL
      locale: const Locale('ar'),
      supportedLocales: const [
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,

      home: const MainNavigationScreen(),
    );
  }
}
