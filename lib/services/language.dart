/// Langues prises en charge pour la traduction.
class AppLanguage {
  final String code;
  final String name;
  final String flag;
  const AppLanguage(this.code, this.name, this.flag);
}

const supportedLanguages = <AppLanguage>[
  AppLanguage('en', 'Anglais', '🇬🇧'),
  AppLanguage('fr', 'Français', '🇫🇷'),
  AppLanguage('es', 'Espagnol', '🇪🇸'),
  AppLanguage('pt', 'Portugais', '🇵🇹'),
  AppLanguage('de', 'Allemand', '🇩🇪'),
  AppLanguage('it', 'Italien', '🇮🇹'),
  AppLanguage('ja', 'Japonais', '🇯🇵'),
  AppLanguage('ko', 'Coréen', '🇰🇷'),
  AppLanguage('zh', 'Chinois', '🇨🇳'),
  AppLanguage('ar', 'Arabe', '🇸🇦'),
  AppLanguage('sw', 'Swahili', '🇰🇪'),
];

AppLanguage languageOf(String code) => supportedLanguages.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage(code, code.toUpperCase(), '🌐'),
    );

/// Détection simple de la langue d'un texte (heuristique par mots fréquents).
class LanguageGuesser {
  static const _common = <String, List<String>>{
    'en': ['the', 'you', 'and', 'i', 'my', 'me', 'is', 'it', 'to', 'love', 'your', 'in', 'on', 'don\'t', 'i\'m'],
    'fr': ['je', 'tu', 'le', 'la', 'les', 'et', 'de', 'des', 'est', 'pas', 'que', 'mon', 'ma', 'un', 'une', 'moi', 'toi'],
    'es': ['el', 'la', 'que', 'y', 'de', 'en', 'yo', 'tu', 'mi', 'por', 'con', 'no', 'es', 'amor', 'te', 'quiero'],
    'pt': ['eu', 'você', 'que', 'não', 'de', 'meu', 'minha', 'em', 'um', 'uma', 'com', 'pra', 'amor', 'é', 'o'],
    'de': ['ich', 'du', 'und', 'die', 'der', 'das', 'nicht', 'ist', 'mein', 'mich', 'dich', 'ein', 'zu'],
    'it': ['io', 'tu', 'che', 'il', 'non', 'di', 'per', 'mi', 'ti', 'sono', 'amore', 'una', 'come'],
  };

  static String guess(String text) {
    if (RegExp(r'[぀-ヿ]').hasMatch(text)) return 'ja';
    if (RegExp(r'[가-힯]').hasMatch(text)) return 'ko';
    if (RegExp(r'[一-鿿]').hasMatch(text)) return 'zh';
    if (RegExp(r'[؀-ۿ]').hasMatch(text)) return 'ar';

    final words = text
        .toLowerCase()
        .split(RegExp(r"[^\p{L}']+", unicode: true))
        .where((w) => w.isNotEmpty)
        .toList();
    var best = 'en';
    var bestScore = 0;
    _common.forEach((lang, list) {
      final set = list.toSet();
      final score = words.where(set.contains).length;
      if (score > bestScore) {
        bestScore = score;
        best = lang;
      }
    });
    return best;
  }
}
