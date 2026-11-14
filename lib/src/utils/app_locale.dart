import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

abstract final class AppLocale {
  static final supported = List<Locale>.unmodifiable([
    const Locale('pt'),
    for (final code in (kMaterialSupportedLanguages.toList()..sort()))
      if (code != 'pt') Locale(code),
    const Locale('pt', 'BR'),
    const Locale('pt', 'PT'),
    const Locale('zh', 'CN'),
    const Locale('zh', 'TW'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
  ]);

  static Locale? fromPreference(String tag) {
    for (final locale in supported) {
      if (locale.toLanguageTag() == tag) return locale;
    }
    return null;
  }

  static String pickerTitle(BuildContext context) =>
      switch (Localizations.localeOf(context).languageCode) {
        'en' => 'App language',
        'es' => 'Idioma de la aplicación',
        'fr' => 'Langue de l’application',
        _ => 'Idioma do aplicativo',
      };

  static String systemLabel(BuildContext context) =>
      switch (Localizations.localeOf(context).languageCode) {
        'en' => 'System language',
        'es' => 'Idioma del sistema',
        'fr' => 'Langue du système',
        _ => 'Idioma do sistema',
      };

  static String label(Locale? locale) {
    if (locale == null) return 'Idioma do sistema';
    final tag = locale.toLanguageTag();
    final name = _names[tag] ?? _names[locale.languageCode] ?? tag;
    return name == tag ? tag : '$name ($tag)';
  }

  static const _names = {
    'pt-BR': 'Português do Brasil',
    'pt-PT': 'Português de Portugal',
    'zh-CN': '简体中文（中国）',
    'zh-TW': '繁體中文（台灣）',
    'zh-Hans': '简体中文',
    'zh-Hant': '繁體中文',
    'af': 'Afrikaans',
    'am': 'አማርኛ',
    'ar': 'العربية',
    'as': 'অসমীয়া',
    'az': 'azərbaycan',
    'be': 'беларуская',
    'bg': 'български',
    'bn': 'বাংলা',
    'bo': 'བོད་སྐད་',
    'bs': 'bosanski',
    'ca': 'català',
    'cs': 'čeština',
    'cy': 'Cymraeg',
    'da': 'dansk',
    'de': 'Deutsch',
    'el': 'Ελληνικά',
    'en': 'English',
    'es': 'español',
    'et': 'eesti',
    'eu': 'euskara',
    'fa': 'فارسی',
    'fi': 'suomi',
    'fil': 'Filipino',
    'fr': 'français',
    'ga': 'Gaeilge',
    'gl': 'galego',
    'gsw': 'Schwiizertüütsch',
    'gu': 'ગુજરાતી',
    'he': 'עברית',
    'hi': 'हिन्दी',
    'hr': 'hrvatski',
    'hu': 'magyar',
    'hy': 'հայերեն',
    'id': 'Indonesia',
    'is': 'íslenska',
    'it': 'italiano',
    'ja': '日本語',
    'ka': 'ქართული',
    'kk': 'қазақ тілі',
    'km': 'ខ្មែរ',
    'kn': 'ಕನ್ನಡ',
    'ko': '한국어',
    'ky': 'кыргызча',
    'lo': 'ລາວ',
    'lt': 'lietuvių',
    'lv': 'latviešu',
    'mk': 'македонски',
    'ml': 'മലയാളം',
    'mn': 'монгол',
    'mr': 'मराठी',
    'ms': 'Melayu',
    'my': 'မြန်မာ',
    'nb': 'norsk bokmål',
    'ne': 'नेपाली',
    'nl': 'Nederlands',
    'no': 'norsk',
    'or': 'ଓଡ଼ିଆ',
    'pa': 'ਪੰਜਾਬੀ',
    'pl': 'polski',
    'ps': 'پښتو',
    'pt': 'português',
    'ro': 'română',
    'ru': 'русский',
    'si': 'සිංහල',
    'sk': 'slovenčina',
    'sl': 'slovenščina',
    'sq': 'shqip',
    'sr': 'српски',
    'sv': 'svenska',
    'sw': 'Kiswahili',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'th': 'ไทย',
    'tl': 'Tagalog',
    'tr': 'Türkçe',
    'ug': 'ئۇيغۇرچە',
    'uk': 'українська',
    'ur': 'اردو',
    'uz': 'o‘zbek',
    'vi': 'Tiếng Việt',
    'zh': '中文',
    'zu': 'isiZulu',
  };
}

class AppLanguageDialog extends StatelessWidget {
  const AppLanguageDialog({super.key, required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    final locales = [...AppLocale.supported]
      ..sort((a, b) => AppLocale.label(a).compareTo(AppLocale.label(b)));
    final effectiveSelection =
        AppLocale.fromPreference(selected)?.toLanguageTag() ?? '';
    return SimpleDialog(
      title: Text(AppLocale.pickerTitle(context)),
      children: [
        for (final locale in <Locale?>[null, ...locales])
          ListTile(
            title: Text(
              locale == null
                  ? AppLocale.systemLabel(context)
                  : AppLocale.label(locale),
            ),
            selected: (locale?.toLanguageTag() ?? '') == effectiveSelection,
            onTap: () => Navigator.pop(context, locale?.toLanguageTag() ?? ''),
          ),
      ],
    );
  }
}
