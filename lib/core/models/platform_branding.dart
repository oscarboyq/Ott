import 'package:equatable/equatable.dart';
import 'package:video/core/constants/app_strings.dart';

class PlatformBranding extends Equatable {
  final String name;
  final String tagline;
  final String? logoUrl;
  final String? faviconUrl;
  final String? supportEmail;
  final String? termsUrl;
  final String? privacyUrl;
  final String? copyrightText;
  final String? platformNotice;

  const PlatformBranding({
    this.name = AppStrings.appName,
    this.tagline = AppStrings.tagline,
    this.logoUrl,
    this.faviconUrl,
    this.supportEmail,
    this.termsUrl,
    this.privacyUrl,
    this.copyrightText,
    this.platformNotice,
  });

  bool get hasCustomLogo => logoUrl != null && logoUrl!.trim().isNotEmpty;
  bool get hasCustomFavicon => faviconUrl != null && faviconUrl!.trim().isNotEmpty;
  bool get hasPlatformNotice =>
      platformNotice != null && platformNotice!.trim().isNotEmpty;

  String get tabTitle {
    final hasCustomTagline = tagline.isNotEmpty &&
        tagline != AppStrings.tagline;
    return hasCustomTagline ? '$name – $tagline' : name;
  }


  PlatformBranding copyWith({
    String? name,
    String? tagline,
    String? logoUrl,
    String? faviconUrl,
    String? supportEmail,
    String? termsUrl,
    String? privacyUrl,
    String? copyrightText,
    String? platformNotice,
  }) {
    return PlatformBranding(
      name: name ?? this.name,
      tagline: tagline ?? this.tagline,
      logoUrl: logoUrl ?? this.logoUrl,
      faviconUrl: faviconUrl ?? this.faviconUrl,
      supportEmail: supportEmail ?? this.supportEmail,
      termsUrl: termsUrl ?? this.termsUrl,
      privacyUrl: privacyUrl ?? this.privacyUrl,
      copyrightText: copyrightText ?? this.copyrightText,
      platformNotice: platformNotice ?? this.platformNotice,
    );
  }

  factory PlatformBranding.fromSettings(Map<String, String> settings) {
    final rawName = settings['app_name']?.trim();
    final rawTagline = settings['app_tagline']?.trim();
    final rawLogo = settings['app_logo_url']?.trim();
    final rawFavicon = settings['app_favicon_url']?.trim();
    final rawEmail = settings['support_email']?.trim();
    final rawTerms = settings['terms_url']?.trim();
    final rawPrivacy = settings['privacy_url']?.trim();
    final rawCopyright = settings['copyright_text']?.trim();
    final rawNotice = settings['platform_notice']?.trim();

    return PlatformBranding(
      name: (rawName != null && rawName.isNotEmpty) ? rawName : AppStrings.appName,
      tagline: (rawTagline != null && rawTagline.isNotEmpty) ? rawTagline : AppStrings.tagline,
      logoUrl: (rawLogo != null && rawLogo.isNotEmpty) ? rawLogo : null,
      faviconUrl: (rawFavicon != null && rawFavicon.isNotEmpty) ? rawFavicon : null,
      supportEmail: (rawEmail != null && rawEmail.isNotEmpty) ? rawEmail : null,
      termsUrl: (rawTerms != null && rawTerms.isNotEmpty) ? rawTerms : null,
      privacyUrl: (rawPrivacy != null && rawPrivacy.isNotEmpty) ? rawPrivacy : null,
      copyrightText: (rawCopyright != null && rawCopyright.isNotEmpty)
          ? rawCopyright
          : '© ${DateTime.now().year} ${(rawName != null && rawName.isNotEmpty) ? rawName : AppStrings.appName}. All rights reserved.',
      platformNotice: (rawNotice != null && rawNotice.isNotEmpty) ? rawNotice : null,
    );
  }

  @override
  List<Object?> get props => [
        name,
        tagline,
        logoUrl,
        faviconUrl,
        supportEmail,
        termsUrl,
        privacyUrl,
        copyrightText,
        platformNotice,
      ];
}
