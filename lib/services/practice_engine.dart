import 'dart:math';

import '../models/song.dart';

final RegExp _nonWord = RegExp(r"[^\p{L}\p{N}']", unicode: true);

String normalizeWord(String w) => w.replaceAll(_nonWord, '').toLowerCase();

/// Une carte « devine la ligne suivante ».
class FlashCard {
  final int promptIndex;
  final int answerIndex;
  const FlashCard(this.promptIndex, this.answerIndex);
}

/// Une question « texte à trous ».
class ClozeQuestion {
  final int lineIndex;
  final List<String> tokens;
  final int blankToken;
  final String answer;
  final List<String> choices;

  const ClozeQuestion({
    required this.lineIndex,
    required this.tokens,
    required this.blankToken,
    required this.answer,
    required this.choices,
  });
}

/// Une question « remets les lignes dans l'ordre ».
class OrderQuestion {
  final List<int> correct;
  final List<int> shuffled;
  const OrderQuestion(this.correct, this.shuffled);
}

/// Génère les exercices d'entraînement à partir d'une chanson.
class PracticeEngine {
  final Song song;
  final Random _rng;

  PracticeEngine(this.song, {Random? random}) : _rng = random ?? Random();

  List<int> get _textIdx => song.textIndexes;

  /// Lignes triées par maîtrise croissante (les plus faibles d'abord).
  List<int> _weakestFirst(List<int> idx) {
    final list = [...idx]..shuffle(_rng);
    list.sort((a, b) => song.levelOf(a).compareTo(song.levelOf(b)));
    return list;
  }

  List<FlashCard> flashCards({int count = 10}) {
    final idx = _textIdx;
    if (idx.length < 2) return [];
    final pairs = <FlashCard>[];
    for (var k = 0; k < idx.length - 1; k++) {
      pairs.add(FlashCard(idx[k], idx[k + 1]));
    }
    pairs.shuffle(_rng);
    pairs.sort((a, b) =>
        song.levelOf(a.answerIndex).compareTo(song.levelOf(b.answerIndex)));
    return pairs.take(count).toList();
  }

  List<String> get _vocabulary {
    final seen = <String>{};
    final out = <String>[];
    for (final i in _textIdx) {
      for (final t in song.lines[i].text.split(RegExp(r'\s+'))) {
        final n = normalizeWord(t);
        if (n.length >= 3 && seen.add(n)) out.add(n);
      }
    }
    return out;
  }

  List<ClozeQuestion> cloze({int count = 10}) {
    final vocab = _vocabulary;
    final out = <ClozeQuestion>[];
    for (final i in _weakestFirst(_textIdx)) {
      if (out.length >= count) break;
      final tokens = song.lines[i].text.split(RegExp(r'\s+'));
      final candidates = [
        for (var t = 0; t < tokens.length; t++)
          if (normalizeWord(tokens[t]).length >= 3) t
      ];
      if (candidates.isEmpty) continue;
      final blank = candidates[_rng.nextInt(candidates.length)];
      final answer = normalizeWord(tokens[blank]);
      final distractors = vocab.where((w) => w != answer).toList()..shuffle(_rng);
      final choices = <String>[answer, ...distractors.take(3)];
      if (choices.length < 2) continue;
      choices.shuffle(_rng);
      out.add(ClozeQuestion(
        lineIndex: i,
        tokens: tokens,
        blankToken: blank,
        answer: answer,
        choices: choices,
      ));
    }
    return out;
  }

  List<OrderQuestion> order({int count = 4, int size = 4}) {
    final idx = _textIdx;
    if (idx.length < 3) return [];
    final n = min(size, idx.length);
    final starts = List.generate(idx.length - n + 1, (s) => s)..shuffle(_rng);
    final out = <OrderQuestion>[];
    for (final s in starts.take(count)) {
      final correct = idx.sublist(s, s + n);
      final shuffled = [...correct];
      var guard = 0;
      do {
        shuffled.shuffle(_rng);
        guard++;
      } while (_same(shuffled, correct) && guard < 10);
      out.add(OrderQuestion(correct, shuffled));
    }
    return out;
  }

  static bool _same(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Pour le mode « mémoire progressive » : un mot est-il masqué au niveau donné ?
  /// 0 = tout visible, 1 = 1 mot sur 3, 2 = 2 sur 3, 3 = initiales, 4 = tout caché.
  static bool isHidden(int line, int token, int level) {
    if (level <= 0) return false;
    if (level >= 3) return true;
    final h = ((line * 31 + token * 17) ^ (line + token * 7)) % 3;
    return level == 1 ? h == 0 : h != 2;
  }

  static String maskWord(String word, int level) {
    if (level == 3 && word.isNotEmpty) {
      final first = word.characters0;
      return first + '_' * (word.length - first.length).clamp(0, 12);
    }
    return '_' * word.length.clamp(1, 12);
  }
}

extension on String {
  /// Premier caractère « lettre » (en gardant la ponctuation de tête).
  String get characters0 {
    final m = RegExp(r"^[^\p{L}\p{N}]*[\p{L}\p{N}]", unicode: true).firstMatch(this);
    return m?.group(0) ?? (isEmpty ? '' : this[0]);
  }
}
