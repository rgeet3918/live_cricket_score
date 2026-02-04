import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics Service
/// Handles app analytics tracking
class FirebaseAnalyticsService {
  static FirebaseAnalytics? _analytics;
  static FirebaseAnalyticsObserver? _observer;

  /// Initialize Firebase Analytics
  static Future<void> initialize() async {
    try {
      _analytics = FirebaseAnalytics.instance;
      _observer = FirebaseAnalyticsObserver(analytics: _analytics!);
      
      // Log app open event
      await logAppOpen();
      
      if (kDebugMode) {
        print('✅ Firebase Analytics initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Firebase Analytics: $e');
      }
    }
  }

  /// Log app open event
  static Future<void> logAppOpen() async {
    try {
      await _analytics?.logAppOpen();
      if (kDebugMode) {
        print('📊 Logged app open event');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error logging app open: $e');
      }
    }
  }

  /// Log screen view
  static Future<void> logScreenView(String screenName) async {
    try {
      await _analytics?.logScreenView(screenName: screenName);
      if (kDebugMode) {
        print('📊 Logged screen view: $screenName');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error logging screen view: $e');
      }
    }
  }

  /// Log custom event
  static Future<void> logEvent({
    required String name,
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics?.logEvent(
        name: name,
        parameters: parameters,
      );
      if (kDebugMode) {
        print('📊 Logged event: $name');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error logging event: $e');
      }
    }
  }

  /// Get analytics observer for navigation
  static FirebaseAnalyticsObserver? get observer => _observer;

  /// Get analytics instance
  static FirebaseAnalytics? get analytics => _analytics;
}
