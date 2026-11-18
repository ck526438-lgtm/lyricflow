import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:lyricflow/data/demo_songs.dart';
import 'package:lyricflow/models/song.dart';
import 'package:lyricflow/services/language.dart';
import 'package:lyricflow/services/lrc_parser.dart';
import 'package:lyricflow/services/practice_engine.dart';

void main() {
  group('LrcParser', () {
    test('lit les balises de temps et les métadonnées', () {
      final p = LrcParser.parseLrc('''
[ti:Titre]
[ar:Artiste]
[00:01.50]Première ligne
[00:04.123]Deuxième ligne
[01:02]Troisième
''');
      expect(p.title, 'Titre');
      expect(p.artist, 'Artiste');
      expect(p.lines.length, 3);
      expect(p.lines[0].time, const Duration(seconds: 1, milliseconds: 500));
      expect(p.lines[1].time, const Duration(seconds: 4, milliseconds: 123));
      expect(p.lines[2].time, const Duration(minutes: 1, seconds: 2));
    });

    test('gère plusieurs balises sur une ligne et trie', () {
      final p = LrcParser.parseLrc('[00:10.00][00:02.00]Refrain\n[00:05.00]Couplet');
      expect(p.lines.map((l) => l.text).toList(), ['Refrain', 'Couplet', 'Refrain']);
    });

    test('applique l\'offset et retire les balises de mots', () {
      final p = LrcParser.parseLrc('[offset:500]\n[00:02.00]<00:02.00>Bon<00:02.50>jour');
      expect(p.lines.single.time, const Duration(milliseconds: 1500));
      expect(p.lines.single.text, 'Bonjour');
    });

    test('détecte le texte brut', () {
      final p = LrcParser.parse('Ligne 1\n\nLigne 2');
      expect(p.isSynced, isFalse);
      expect(p.lines.length, 2);
    });

    test('export LRC relisible', () {
      final lines = [
        const LyricLine(Duration(seconds: 3, milliseconds: 250), 'Salut'),
      ];
      final back = LrcParser.parseLrc(LrcParser.toLrc(lines));
      expect(back.lines.single.time, const Duration(seconds: 3, milliseconds: 250));
    });
  });

  group('LyricTimeline', () {
    final lines = [
      const LyricLine(Duration(seconds: 1), 'a'),
      const LyricLine(Duration(seconds: 5), 'b'),
      const LyricLine(Duration(seconds: 9), 'c'),
    ];
    test('trouve la ligne active', () {
      expect(LyricTimeline.activeIndex(lines, Duration.zero), -1);
      expect(LyricTimeline.activeIndex(lines, const Duration(seconds: 1)), 0);
      expect(LyricTimeline.activeIndex(lines, const Duration(seconds: 6)), 1);
      expect(LyricTimeline.activeIndex(lines, const Duration(seconds: 60)), 2);
    });
    test('fin de ligne', () {
      expect(LyricTimeline.endOf(lines, 0, const Duration(seconds: 20)),
          const Duration(seconds: 5));
      expect(LyricTimeline.endOf(lines, 2, const Duration(seconds: 20)),
          const Duration(seconds: 20));
    });
  });

  group('Song', () {
    test('sérialisation aller-retour', () {
      final s = buildDemoSongs().first
        ..translations[0] = 'Monte le son'
        ..notes[1] = 'note'
        ..mastery[0] = 3
        ..favorite = true;
      final back = Song.fromJson(s.toJson());
      expect(back.title, s.title);
      expect(back.lines.length, s.lines.length);
      expect(back.translations[0], 'Monte le son');
      expect(back.notes[1], 'note');
      expect(back.levelOf(0), 3);
      expect(back.favorite, isTrue);
    });

    test('progression bornée', () {
      final s = buildDemoSongs().first;
      expect(s.progress, 0);
      for (final i in s.textIndexes) {
        s.bump(i, true);
        s.bump(i, true);
        s.bump(i, true);
        s.bump(i, true);
        s.bump(i, true);
        s.bump(i, true);
      }
      expect(s.progress, 1);
      s.bump(s.textIndexes.first, false);
      expect(s.levelOf(s.textIndexes.first), Song.maxLevel - 1);
    });
  });

  group('PracticeEngine', () {
    final song = buildDemoSongs().first;
    final engine = PracticeEngine(song, random: Random(42));

    test('flashcards : ligne suivante', () {
      final cards = engine.flashCards();
      expect(cards, isNotEmpty);
      for (final c in cards) {
        expect(c.answerIndex, greaterThan(c.promptIndex));
        expect(song.lines[c.answerIndex].isBreak, isFalse);
      }
    });

    test('texte à trous : la bonne réponse est proposée', () {
      for (final q in engine.cloze()) {
        expect(q.choices, contains(q.answer));
        expect(q.choices.toSet().length, q.choices.length);
        expect(normalizeWord(q.tokens[q.blankToken]), q.answer);
      }
    });

    test('ordre : mélange différent de la solution', () {
      for (final q in engine.order()) {
        expect(q.shuffled.toSet(), q.correct.toSet());
      }
    });

    test('masquage progressif', () {
      expect(PracticeEngine.isHidden(0, 0, 0), isFalse);
      expect(PracticeEngine.isHidden(3, 2, 4), isTrue);
      expect(PracticeEngine.maskWord('Bonjour', 3), 'B______');
    });
  });

  test('détection de langue', () {
    expect(LanguageGuesser.guess('I love you and you love me'), 'en');
    expect(LanguageGuesser.guess('je t\'aime et tu es mon amour, moi et toi'), 'fr');
    expect(LanguageGuesser.guess('yo te quiero con todo mi amor'), 'es');
  });
}
