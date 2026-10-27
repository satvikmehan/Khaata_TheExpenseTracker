import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'screens/auth/login_screen.dart';
import 'screens/groups/groups_screen.dart';
import 'services/auth_service.dart';
import 'services/group_service.dart';
import 'services/udhaar_service.dart';
import 'services/splitwise_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options != null) {
      await Firebase.initializeApp(options: options);
    } else {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  await AuthService.instance.initialize();
  await GroupService.instance.initialize();
  await UdhaarService.instance.initialize();
  await SplitwiseService.instance.initialize();
  runApp(const ExpenseTrackerApp());
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Khaata',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F172A), // Restrained Slate 900
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF0F172A),
          outline: Color(0xFFCBD5E1),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontSize: 18.0,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
          iconTheme: IconThemeData(
            color: Color(0xFF0F172A),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F172A),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.0),
            ),
            textStyle: const TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.0),
            ),
            textStyle: const TextStyle(
              fontSize: 14.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 14.0,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4.0),
            borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
          ),
        ),
      ),
      home: StreamBuilder<UserModel?>(
        stream: AuthService.instance.authStateChanges,
        initialData: AuthService.instance.currentUser,
        builder: (context, snapshot) {
          final user = snapshot.data ?? AuthService.instance.currentUser;
          if (user != null) {
            return const GroupsScreen();
          }

          return const LoginScreen();
        },
      ),
    );
  }
}
