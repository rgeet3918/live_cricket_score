import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_project/cricket_app/cricket_app.dart';
import 'package:flutter_project/cricket_app/shared/services/firebase_analytics_service.dart';
import 'package:flutter_project/cricket_app/shared/services/firebase_remote_config_service.dart';
import 'package:flutter_project/cricket_app/shared/services/cricket_ad_service.dart';

/// Cricket App Main Entry Point
/// To run cricket app, use this file as entry point
/// Or modify shared_main.dart to conditionally launch cricket app
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env (CRICKET_API_KEY etc.) - fails if .env missing or empty
  await dotenv.load(fileName: '.env');

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  try {
    // TODO: Add firebase_options.dart file after running flutterfire configure
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    // );

    // For now, initialize services (they will handle errors gracefully)
    await FirebaseRemoteConfigService.initialize();
    await FirebaseAnalyticsService.initialize();
    await CricketAdService.initialize();
  } catch (e) {
    debugPrint('⚠️ Firebase initialization error: $e');
    debugPrint('ℹ️ Make sure to run: flutterfire configure');
  }

  runApp(const ProviderScope(child: CricketApp()));
}
