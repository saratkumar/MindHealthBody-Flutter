import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'booking_provider.dart';
import 'firebase_options.dart';
import 'home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    runApp(_FirebaseErrorApp(message: e.toString()));
    return;
  }
  runApp(const MbPracticeApp());
}

class _FirebaseErrorApp extends StatelessWidget {
  final String message;
  const _FirebaseErrorApp({required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Firebase init failed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Brand palette
const kBrandLightBlue = Color(0xFF8ECAE6);
const kBrandTeal = Color(0xFF219EBC);
const kBrandNavy = Color(0xFF023047);
const kBrandAmber = Color(0xFFFFB703);
const kBrandOrange = Color(0xFFFB8500);

class MbPracticeApp extends StatelessWidget {
  const MbPracticeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: kBrandNavy,
      brightness: Brightness.light,
    ).copyWith(
      secondary: kBrandTeal,
      tertiary: kBrandAmber,
    );

    final baseTextTheme = ThemeData(brightness: Brightness.light).textTheme;
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).copyWith(
      headlineSmall: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: kBrandNavy),
      titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: kBrandNavy),
      titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600),
    );

    return ChangeNotifierProvider(
      create: (_) => BookingProvider(),
      child: MaterialApp(
        title: 'MBPractice',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: colorScheme,
          useMaterial3: true,
          textTheme: textTheme,
          scaffoldBackgroundColor: const Color(0xFFF7F9FC),
          appBarTheme: AppBarTheme(
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 1,
            backgroundColor: const Color(0xFFF7F9FC),
            foregroundColor: kBrandNavy,
            titleTextStyle: GoogleFonts.poppins(
              color: kBrandNavy,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey.shade200),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBrandTeal, width: 1.5),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12,
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBrandTeal,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: kBrandNavy,
              side: const BorderSide(color: kBrandNavy, width: 1.5),
              minimumSize: const Size.fromHeight(48),
              textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            elevation: 1,
            indicatorColor: kBrandLightBlue.withValues(alpha: 0.45),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return GoogleFonts.inter(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? kBrandNavy : Colors.grey.shade600,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(color: selected ? kBrandNavy : Colors.grey.shade500);
            }),
          ),
          dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
