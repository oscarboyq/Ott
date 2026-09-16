import 'package:flutter_test/flutter_test.dart';
import 'package:video/core/constants/app_strings.dart';
import 'package:video/core/models/platform_branding.dart';
import 'package:video/core/services/app_settings_service.dart';

void main() {
  group('PlatformBranding', () {
    test('uses defaults when settings are empty', () {
      final branding = PlatformBranding.fromSettings(const {});

      expect(branding.name, AppStrings.appName);
      expect(branding.tagline, AppStrings.tagline);
      expect(branding.logoUrl, isNull);
      expect(branding.faviconUrl, isNull);
      expect(branding.supportEmail, isNull);
      expect(branding.termsUrl, isNull);
      expect(branding.privacyUrl, isNull);
      expect(branding.platformNotice, isNull);
      expect(branding.hasCustomLogo, isFalse);
      expect(branding.hasCustomFavicon, isFalse);
      expect(branding.hasPlatformNotice, isFalse);
      expect(branding.copyrightText, contains(AppStrings.appName));
    });

    test('parses custom branding values correctly', () {
      final settings = {
        SettingKeys.appName: 'CineSphere',
        SettingKeys.appTagline: 'Stream unlimited movies, series',
        SettingKeys.appLogoUrl: 'https://cdn.example.com/logo.png',
        SettingKeys.appFaviconUrl: 'https://cdn.example.com/favicon.ico',
        SettingKeys.supportEmail: 'help@cinesphere.tv',
        SettingKeys.termsUrl: 'https://cinesphere.tv/terms',
        SettingKeys.privacyUrl: 'https://cinesphere.tv/privacy',
        SettingKeys.copyrightText: '© 2026 CineSphere Media LLC',
        SettingKeys.platformNotice: 'New 4K HDR series added weekly',
      };

      final branding = PlatformBranding.fromSettings(settings);

      expect(branding.name, 'CineSphere');
      expect(branding.tagline, 'Stream unlimited movies, series');
      expect(branding.logoUrl, 'https://cdn.example.com/logo.png');
      expect(branding.faviconUrl, 'https://cdn.example.com/favicon.ico');
      expect(branding.supportEmail, 'help@cinesphere.tv');
      expect(branding.termsUrl, 'https://cinesphere.tv/terms');
      expect(branding.privacyUrl, 'https://cinesphere.tv/privacy');
      expect(branding.copyrightText, '© 2026 CineSphere Media LLC');
      expect(branding.platformNotice, 'New 4K HDR series added weekly');
      expect(branding.hasCustomLogo, isTrue);
      expect(branding.hasCustomFavicon, isTrue);
      expect(branding.hasPlatformNotice, isTrue);
    });

    test('falls back gracefully when settings have whitespace or empty strings', () {
      final settings = {
        SettingKeys.appName: '   ',
        SettingKeys.appTagline: '   ',
        SettingKeys.appLogoUrl: '',
        SettingKeys.appFaviconUrl: '   ',
        SettingKeys.platformNotice: '   ',
      };

      final branding = PlatformBranding.fromSettings(settings);

      expect(branding.name, AppStrings.appName);
      expect(branding.tagline, AppStrings.tagline);
      expect(branding.logoUrl, isNull);
      expect(branding.faviconUrl, isNull);
      expect(branding.platformNotice, isNull);
      expect(branding.hasCustomLogo, isFalse);
      expect(branding.hasCustomFavicon, isFalse);
      expect(branding.hasPlatformNotice, isFalse);
    });

    test('copyWith properly overrides specified attributes', () {
      const initial = PlatformBranding(
        name: 'StreamOTT',
        tagline: 'Initial Tagline',
        logoUrl: 'https://cdn.example.com/logo.png',
      );

      final updated = initial.copyWith(
        name: 'NewOTT',
        tagline: 'Stream unlimited movies, series',
      );

      expect(updated.name, 'NewOTT');
      expect(updated.tagline, 'Stream unlimited movies, series');
      expect(updated.logoUrl, 'https://cdn.example.com/logo.png');
      expect(updated.hasCustomLogo, isTrue);
    });

    test('tabTitle returns name only when tagline is default or empty', () {
      const defaultBranding = PlatformBranding(
        name: 'ReelHouse',
        tagline: AppStrings.tagline,
      );
      expect(defaultBranding.tabTitle, 'ReelHouse');

      const emptyTagline = PlatformBranding(
        name: 'ReelHouse',
        tagline: '',
      );
      expect(emptyTagline.tabTitle, 'ReelHouse');
    });

    test('tabTitle returns name and tagline when tagline is customized', () {
      const custom = PlatformBranding(
        name: 'ReelHouse',
        tagline: 'Stream unlimited movies, series',
      );
      expect(custom.tabTitle, 'ReelHouse – Stream unlimited movies, series');
    });
  });
}
