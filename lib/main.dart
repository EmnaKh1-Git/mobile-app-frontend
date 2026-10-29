import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/theme.dart';
import 'core/services/supabase_service.dart';
import 'features/trajet/services/trajet_service.dart';
import 'screens/accueil_page.dart';
import 'features/user/screens/login_page.dart';
import 'features/user/screens/register_page.dart';
import 'features/user/screens/forgot_password_page.dart';
import 'features/user/screens/profile_page.dart';
import 'features/user/screens/privacy_policy_page.dart';
import 'features/onboarding/screens/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);

  await SupabaseService.initialize();

  // Module Trajets : lit les trajets dans SQLite avant d'afficher l'accueil
  await TrajetService.instance.charger();

  runApp(const UniDriveApp());
}

class UniDriveApp extends StatelessWidget {
  const UniDriveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniDrive',
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaire,
          primary: AppColors.primaire,
          secondary: AppColors.accent,
          surface: AppColors.fond,
        ),
        scaffoldBackgroundColor: AppColors.fond,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.primaire,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaire,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.champFond,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primaire, width: 1.6),
          ),
        ),
      ),
      home: const AppStartupPage(),
      routes: {
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/accueil': (context) => const AccueilPage(),
        '/profile': (context) => const ProfilePage(),
        '/privacy-policy': (context) => const PrivacyPolicyPage(),
      },
    );
  }
}
