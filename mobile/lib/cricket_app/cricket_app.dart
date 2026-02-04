import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';
import 'constants/cricket_colors.dart';
import 'shared/services/firebase_analytics_service.dart';

/// Main Cricket App Entry Point
/// This is the root widget for the cricket app feature
class CricketApp extends StatelessWidget {
  const CricketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cricket App',
      debugShowCheckedModeBanner: false,
      // Add analytics observer for automatic screen tracking
      navigatorObservers: [
        if (FirebaseAnalyticsService.observer != null)
          FirebaseAnalyticsService.observer!,
      ],
      theme: ThemeData(
        primaryColor: CricketColors.primaryGreen,
        scaffoldBackgroundColor: CricketColors.backgroundDark,
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: CricketColors.primaryGreen,
          background: CricketColors.backgroundDark,
          surface: CricketColors.cardBackground,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
