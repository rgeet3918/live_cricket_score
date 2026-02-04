import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Firebase Remote Config Service
/// Handles remote configuration for ad control and feature flags
class FirebaseRemoteConfigService {
  static FirebaseRemoteConfig? _remoteConfig;
  static bool _isInitialized = false;

  // Default values
  static const Map<String, dynamic> _defaults = {
    'ads_enabled': true,
    'banner_ads_enabled': true,
    'interstitial_ads_enabled': true,
    'rewarded_ads_enabled': true,
    'ad_frequency': 3, // Show ad after every 3 screens
    'ios_adex_enabled': false, // iOS AdEx toggle
    'android_admob_enabled': true, // Android AdMob toggle
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
        print('📊 Ads Enabled: ${adsEnabled}');
        print('📊 Banner Ads: ${bannerAdsEnabled}');
        print('📊 iOS AdEx: ${iosAdExEnabled}');
        print('📊 Android AdMob: ${androidAdMobEnabled}');
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

  /// Check if ads are enabled
  static bool get adsEnabled {
    try {
      return _remoteConfig?.getBool('ads_enabled') ?? _defaults['ads_enabled'] as bool;
    } catch (e) {
      return _defaults['ads_enabled'] as bool;
    }
  }

  /// Check if banner ads are enabled
  static bool get bannerAdsEnabled {
    try {
      return _remoteConfig?.getBool('banner_ads_enabled') ?? _defaults['banner_ads_enabled'] as bool;
    } catch (e) {
      return _defaults['banner_ads_enabled'] as bool;
    }
  }

  /// Check if interstitial ads are enabled
  static bool get interstitialAdsEnabled {
    try {
      return _remoteConfig?.getBool('interstitial_ads_enabled') ?? _defaults['interstitial_ads_enabled'] as bool;
    } catch (e) {
      return _defaults['interstitial_ads_enabled'] as bool;
    }
  }

  /// Check if rewarded ads are enabled
  static bool get rewardedAdsEnabled {
    try {
      return _remoteConfig?.getBool('rewarded_ads_enabled') ?? _defaults['rewarded_ads_enabled'] as bool;
    } catch (e) {
      return _defaults['rewarded_ads_enabled'] as bool;
    }
  }

  /// Get ad frequency (show ad after N screens)
  static int get adFrequency {
    try {
      return _remoteConfig?.getInt('ad_frequency') ?? _defaults['ad_frequency'] as int;
    } catch (e) {
      return _defaults['ad_frequency'] as int;
    }
  }

  /// Check if iOS AdEx is enabled
  static bool get iosAdExEnabled {
    try {
      return _remoteConfig?.getBool('ios_adex_enabled') ?? _defaults['ios_adex_enabled'] as bool;
    } catch (e) {
      return _defaults['ios_adex_enabled'] as bool;
    }
  }

  /// Check if Android AdMob is enabled
  static bool get androidAdMobEnabled {
    try {
      return _remoteConfig?.getBool('android_admob_enabled') ?? _defaults['android_admob_enabled'] as bool;
    } catch (e) {
      return _defaults['android_admob_enabled'] as bool;
    }
  }

  /// Get remote config instance
  static FirebaseRemoteConfig? get remoteConfig => _remoteConfig;
}
