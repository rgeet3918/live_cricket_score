import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config Service
/// Handles remote configuration for ad control and feature flags
class FirebaseRemoteConfigService {
  static FirebaseRemoteConfig? _remoteConfig;
  static bool _isInitialized = false;

  // Default values - Only 2 parameters for ad control
  static const Map<String, dynamic> _defaults = {
    'ads_enabled_android': true, // Android ads toggle
    'ads_enabled_ios': true, // iOS ads toggle
  };

  /// Initialize Firebase Remote Config
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _remoteConfig = FirebaseRemoteConfig.instance;
      
      // Set config settings
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // Set default values
      await _remoteConfig!.setDefaults(_defaults);

      // Fetch and activate
      await _remoteConfig!.fetchAndActivate();

      _isInitialized = true;

      if (kDebugMode) {
        print('✅ Firebase Remote Config initialized');
        print('📊 Android Ads Enabled: ${androidAdsEnabled}');
        print('📊 iOS Ads Enabled: ${iosAdsEnabled}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Remote Config: $e');
      }
      _isInitialized = false;
    }
  }

  /// Fetch latest config from server
  static Future<void> fetchAndActivate() async {
    try {
      if (_remoteConfig != null) {
        await _remoteConfig!.fetchAndActivate();
        if (kDebugMode) {
          print('✅ Remote Config fetched and activated');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error fetching Remote Config: $e');
      }
    }
  }

  /// Check if Android ads are enabled
  static bool get androidAdsEnabled {
    try {
      return _remoteConfig?.getBool('ads_enabled_android') ?? _defaults['ads_enabled_android'] as bool;
    } catch (e) {
      return _defaults['ads_enabled_android'] as bool;
    }
  }

  /// Check if iOS ads are enabled
  static bool get iosAdsEnabled {
    try {
      return _remoteConfig?.getBool('ads_enabled_ios') ?? _defaults['ads_enabled_ios'] as bool;
    } catch (e) {
      return _defaults['ads_enabled_ios'] as bool;
    }
  }

  /// Get remote config instance
  static FirebaseRemoteConfig? get remoteConfig => _remoteConfig;
}
