import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_project/data/local/shared_pref/my_shared_preferences.dart';
import 'package:flutter_project/cricket_app/cricket_app.dart';

Future<void> sharedMain({List<dynamic> overrides = const []}) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env (CRICKET_API_KEY etc.) - fails if .env missing or empty
  await dotenv.load(fileName: '.env');

  // Initialize SharedPreferences
  await SharedPrefManager.init();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: CricketApp()));
}
