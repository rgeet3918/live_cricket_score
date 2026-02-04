import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_remote_config_service.dart';

/// Cricket App Ad Service
/// Handles ads with Remote Config control for iOS AdEx and Android AdMob
class CricketAdService {
  static BannerAd? _bannerAd;
  static int _screenViewCount = 0;

  /// Initialize ads
  static Future<void> initialize() async {
    try {
      // Initialize Remote Config first
      await FirebaseRemoteConfigService.initialize();

      // Check if ads are enabled
      if (!FirebaseRemoteConfigService.adsEnabled) {
        if (kDebugMode) {
          print('📢 Ads are disabled via Remote Config');
        }
        return;
      }

      // Initialize Mobile Ads SDK
      await MobileAds.instance.initialize();

      if (kDebugMode) {
        print('✅ Cricket Ad Service initialized');
        print('📱 Platform: ${Platform.isIOS ? "iOS" : "Android"}');
        print('📢 Ads Enabled: ${FirebaseRemoteConfigService.adsEnabled}');
        
        if (Platform.isIOS) {
          print('📢 iOS AdEx Enabled: ${FirebaseRemoteConfigService.iosAdExEnabled}');
        } else {
          print('📢 Android AdMob Enabled: ${FirebaseRemoteConfigService.androidAdMobEnabled}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing Cricket Ad Service: $e');
      }
    }
  }

  /// Check if ads should be shown
  static bool shouldShowAds() {
    // Check Remote Config
    if (!FirebaseRemoteConfigService.adsEnabled) {
      return false;
    }

    // Platform-specific checks
    if (Platform.isIOS) {
      return FirebaseRemoteConfigService.iosAdExEnabled;
    } else {
      return FirebaseRemoteConfigService.androidAdMobEnabled;
    }
  }

  /// Check if banner ads should be shown
  static bool shouldShowBannerAds() {
    return shouldShowAds() && FirebaseRemoteConfigService.bannerAdsEnabled;
  }

  /// Increment screen view count for ad frequency control
  static void incrementScreenView() {
    _screenViewCount++;
  }

  /// Check if ad should be shown based on frequency
  static bool shouldShowAdByFrequency() {
    final frequency = FirebaseRemoteConfigService.adFrequency;
    return _screenViewCount % frequency == 0;
  }

  /// Get banner ad widget
  static Widget getBannerAdWidget({double? padding}) {
    if (!shouldShowBannerAds()) {
      return const SizedBox.shrink();
    }

    return BannerAdWidget(
      padding: padding,
      adUnitId: _getBannerAdUnitId(),
    );
  }

  /// Get banner ad unit ID based on platform and Remote Config
  static String _getBannerAdUnitId() {
    // Use test IDs for development
    if (kDebugMode) {
      return Platform.isIOS
          ? 'ca-app-pub-3940256099942544/2934735716' // iOS Test ID
          : 'ca-app-pub-3940256099942544/6300978111'; // Android Test ID
    }

    // Production IDs - Update with your actual Ad Unit IDs
    if (Platform.isIOS) {
      // iOS AdEx or AdMob ID
      return 'ca-app-pub-3422720384917984/7003147105'; // TODO: Replace with iOS AdEx ID
    } else {
      // Android AdMob ID
      return 'ca-app-pub-3422720384917984/7003147105'; // TODO: Replace with Android AdMob ID
    }
  }

  /// Load banner ad
  static Future<void> loadBannerAd() async {
    if (!shouldShowBannerAds()) return;

    try {
      if (_bannerAd != null) {
        _bannerAd!.dispose();
      }

      _bannerAd = BannerAd(
        adUnitId: _getBannerAdUnitId(),
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (kDebugMode) {
              print('✅ Banner ad loaded');
            }
          },
          onAdFailedToLoad: (ad, error) {
            if (kDebugMode) {
              print('❌ Banner ad failed to load: ${error.message}');
            }
            ad.dispose();
          },
        ),
      );

      await _bannerAd!.load();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading banner ad: $e');
      }
    }
  }

  /// Dispose banner ad
  static void disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
  }

  /// Show interstitial ad (if enabled and frequency matches)
  static Future<void> showInterstitialAdIfNeeded() async {
    if (!shouldShowAds() || !FirebaseRemoteConfigService.interstitialAdsEnabled) {
      return;
    }

    if (!shouldShowAdByFrequency()) {
      return;
    }

    // Interstitial ad implementation can be added here
    // For now, using the existing RewardedAdService pattern
    if (kDebugMode) {
      print('📢 Interstitial ad should be shown (frequency: ${FirebaseRemoteConfigService.adFrequency})');
    }
  }

  /// Reset screen view count
  static void resetScreenViewCount() {
    _screenViewCount = 0;
  }
}

/// Banner Ad Widget
class BannerAdWidget extends StatefulWidget {
  final double? padding;
  final String adUnitId;

  const BannerAdWidget({super.key, this.padding, required this.adUnitId});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: widget.adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (kDebugMode) {
            print('Banner ad failed: ${error.message}');
          }
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.all(widget.padding ?? 0),
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
