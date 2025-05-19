import 'package:flutter/material.dart';

extension LocaleNameExtension on Locale {
  String toLanguageName() {
    switch (languageCode) {
      case 'en':
        return 'English';
      case 'id':
        return 'Bahasa Indonesia';
      case 'zh':
        switch (countryCode) {
          case 'CN':
            return '简体中文'; // Simplified Chinese
          case 'TW':
            return '繁體中文'; // Traditional Chinese
          default:
            return '中文';
        }
      default:
        return languageCode;
    }
  }
}
