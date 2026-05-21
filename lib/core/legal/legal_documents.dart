import 'package:flutter/widgets.dart';

const String kChaputLegalTrUrl = 'https://chaput.app/legal/tr/';
const String kChaputLegalEnUrl = 'https://chaput.app/legal/en/';

enum LegalDocument {
  terms,
  privacy,
  dataProtection,
  explicitConsent,
  community,
}

extension LegalDocumentX on LegalDocument {
  String get titleKey {
    switch (this) {
      case LegalDocument.terms:
        return 'legal.terms_title';
      case LegalDocument.privacy:
        return 'legal.privacy_title';
      case LegalDocument.dataProtection:
        return 'legal.data_protection_title';
      case LegalDocument.explicitConsent:
        return 'legal.explicit_consent_title';
      case LegalDocument.community:
        return 'legal.community_title';
    }
  }
}

String chaputLegalUrlForLocale(Locale locale, LegalDocument document) {
  final isTurkish = locale.languageCode.toLowerCase() == 'tr';
  final baseUrl = isTurkish ? kChaputLegalTrUrl : kChaputLegalEnUrl;
  final path = switch (document) {
    LegalDocument.terms => 'terms/',
    LegalDocument.privacy => 'privacy/',
    LegalDocument.dataProtection => 'kvkk/',
    LegalDocument.explicitConsent => 'consent/',
    LegalDocument.community => 'community/',
  };
  return '$baseUrl$path';
}
