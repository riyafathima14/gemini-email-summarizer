import 'package:email_summarizer/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Import for kReleaseMode
import 'package:device_preview/device_preview.dart'; // New import for device_preview


// NOTE: You must ensure you have the 'device_preview' package added to your pubspec.yaml

void main() {
  runApp(
    DevicePreview(
      // Enable Device Preview only in debug mode (not production)
      enabled: !kReleaseMode,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Custom Primary Color: 0xFF204ecf (Deep Blue)
  static const Color customPrimaryColor = Color(0xFF204ecf);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Device Preview integration:
      locale: DevicePreview.locale(context), 
      builder: DevicePreview.appBuilder, // Required builder

      debugShowCheckedModeBanner: false,
      title: 'Email Summarizer',
      theme: ThemeData(
        useMaterial3: true,
        // Set the primary seed color
        colorScheme: ColorScheme.fromSeed(
          seedColor: customPrimaryColor,
          primary: customPrimaryColor,
        ),
        // Set global font family (requires Google Fonts package setup)
        fontFamily: 'Nunito', 
        
        // Ensure all AppBar titles use the custom color theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white, // White background for a clean look
          foregroundColor: customPrimaryColor, // Blue text/icons (title, back button)
          elevation: 0, // Removed shadow for a flat, modern look
          centerTitle: false, // <-- MODIFIED: Aligns title to the left with default padding
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: customPrimaryColor, // Explicitly set title color to blue
          ),
        ),
        // Default text button style using the primary color
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: customPrimaryColor,
          ),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
