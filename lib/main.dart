import 'package:email_summarizer/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; 
import 'package:device_preview/device_preview.dart'; 

void main() {
  runApp(
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  static const Color customPrimaryColor = Color(0xFF204ecf);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      locale: DevicePreview.locale(context), 
      builder: DevicePreview.appBuilder, 

      debugShowCheckedModeBanner: false,
      title: 'Email Summarizer',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: customPrimaryColor,
          primary: customPrimaryColor,
        ),
        fontFamily: 'Nunito', 
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: customPrimaryColor,
          elevation: 0, 
          centerTitle: false, 
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: customPrimaryColor, 
          ),
        ),
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
