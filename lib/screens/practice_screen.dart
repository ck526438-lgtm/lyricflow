import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/library_store.dart';
import '../services/practice_engine.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Hub d'entraînement d'une chanson.
class PracticeScreen extends StatelessWidget {
  final String songId;
  const PracticeScreen({super.key, required this.songId});

  @override
  Widget build(BuildContext context) {
    final store = LibraryScope.of(context);
    final song = store.byId(songId);
    if (song == null) {
      return const Scaffold(body: Center(child: Text('Chanson introuvable')));
    }
    final n = song.textIndexes.length;

    void open(Widget page) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('Entraînement')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LF.softGradient,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: LF.violet.withValues(alpha: 0.5)),
            ),
            child: Row(children: [
              ProgressRing(value: song.progress, size: 78, stroke: 7),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(song.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(song.artist, style: const TextStyle(color: LF.muted)),
                  const SizedBox(height: 8),
                  Text('${song.masteredLines}/$n lignes maîtrisées',
                      style: const TextStyle(color: LF.cyan, fontSize: 13)),
                  Text('${song.practiceSessions} séance(s)',
                      style: const TextStyle(color: LF.muted, fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 22),
          const Text('Choisis un exercice',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _ModeCard(
            icon: Icons.style_rounded,
            color: LF.magenta,
            title: 'Flashcards',
            subtitle: 'Devine la ligne qui suit. Les lignes faibles reviennent plus souvent.',
            enabled: n >= 2,
            onTap: () => open(FlashcardsMode(songId: songId)),
          ),
          _ModeCard(
            icon: Icons.text_fields_rounded,
            color: LF.violet,
            title: 'Texte à trous',
            subtitle: 'Retrouve le mot manquant parmi 4 propositions.',
            enabled: n >= 1,
            onTap: () => open(ClozeMode(songId: songId)),
          ),
          _ModeCard(
            icon: Icons.visibility_off_rounded,
            color: LF.blue,
            title: 'Mémoire progressive',
            subtitle: 'Les mots disparaissent petit à petit. Récite de mémoire !',
            enabled: n >= 1,
            onTap: () => open(MemoryMode(songId: songId)),
          ),
          _ModeCard(
            icon: Icons.swap_vert_rounded,
            color: LF.cyan,
            title: 'Remets dans l\'ordre',
            subtitle: 'Reconstitue l\'enchaînement des lignes d\'un couplet.',
            enabled: n >= 3,
            onTap: () => open(OrderMode(songId: songId)),
          ),
          const SizedBox(height: 10),
          if (song.progress > 0)
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: LF.surface,
                      title: const Text('Remettre à zéro ?'),
                      content: const Text(
                          'Ta progression sur cette chanson sera effacée.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annuler')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Effacer',
                                style: TextStyle(color: LF.danger))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    song.mastery.clear();
                    store.update(song);
                  }
                },
                icon: const Icon(Icons.restart_alt_rounded, color: LF.muted),
                label: const Text('Remettre la progression à zéro',
                    style: TextStyle(color: LF.muted)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: enabled ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15.5)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(color: LF.muted, fontSize: 13)),
                  ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: LF.muted),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Base commune : écran de résultat de fin de séance.
// ---------------------------------------------------------------------------

Future<void> _finishSession(
    BuildContext context, Song song, int good, int total) async {
  final store = LibraryScope.read(context);
  await store.recordPractice(song);
  if (!context.mounted) return;
  final ratio = total == 0 ? 0.0 : good / total;
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      backgroundColor: LF.surface,
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const WaveBars(height: 40, bars: 9),
        const SizedBox(height: 16),
        Text(
          ratio >= 0.8
              ? 'Excellent ! 🎤'
              : ratio >= 0.5
                  ? 'Bien joué ! 🎶'
                  : 'Continue, ça rentre ! 💪',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text('$good / $total bonnes réponses',
            style: const TextStyle(color: LF.muted)),
        const SizedBox(height: 16),
        ProgressRing(value: song.progress, size: 80, stroke: 7),
        const SizedBox(height: 6),
        const Text('progression de la chanson',
            style: TextStyle(color: LF.muted, fontSize: 12)),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Terminer'),
        ),
      ],
    ),
  );
  if (context.mounted) Navigator.of(context).pop();
}

class _SessionHeader extends StatelessWidget {
  final int index;
  final int total;
  final int score;
  const _SessionHeader(
      {required this.index, required this.total, required this.score});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : index / total,
              minHeight: 8,
              backgroundColor: LF.border,
              valueColor: const AlwaysStoppedAnimation(LF.violet),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Pill('$score ✓', color: LF.success),
      ]),
    );
  }
}

Song? _songOf(BuildContext context, String id) =>
    LibraryScope.read(context).byId(id);

// ---------------------------------------------------------------------------
// Flashcards
// ---------------------------------------------------------------------------

class FlashcardsMode extends StatefulWidget {
  final String songId;
  const FlashcardsMode({super.key, required this.songId});

  @override
  State<FlashcardsMode> createState() => _FlashcardsModeState();
}

class _FlashcardsModeState extends State<FlashcardsMode> {
  Song? _song;
  List<FlashCard> _cards = [];
  int _i = 0;
  int _good = 0;
  bool _revealed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_song != null) return;
    _song = _songOf(context, widget.songId);
    if (_song != null) _cards = PracticeEngine(_song!).flashCards();
  }

  void _answer(bool knew) {
    final song = _song!;
    song.bump(_cards[_i].answerIndex, knew);
    if (knew) _good++;
    if (_i + 1 >= _cards.length) {
      setState(() => _i++);
      _finishSession(context, song, _good, _cards.length);
      return;
    }
    setState(() {
      _i++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;
    if (song == null || _cards.isEmpty) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Pas assez de lignes pour cet exercice.')));
    }
    final done = _i >= _cards.length;
    final card = _cards[done ? _cards.length - 1 : _i];
    final translation = song.translations[card.answerIndex];

    return Scaffold(
      appBar: AppBar(title: const Text('Flashcards')),
      body: Column(children: [
        _SessionHeader(index: _i, total: _cards.length, score: _good),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              const Text('Après cette ligne…',
                  style: TextStyle(color: LF.muted)),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: LF.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: LF.border),
                ),
                child: Text(song.lines[card.promptIndex].text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 14),
              const Icon(Icons.arrow_downward_rounded, color: LF.violet),
              const SizedBox(height: 14),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _revealed = true),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey('$_i-$_revealed'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        gradient: _revealed ? LF.softGradient : null,
                        color: _revealed ? null : LF.surface2,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                            color: _revealed ? LF.cyan : LF.violet, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: _revealed
                          ? Column(mainAxisSize: MainAxisSize.min, children: [
                              Text(song.lines[card.answerIndex].text,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 22, fontWeight: FontWeight.w900)),
                              if (translation != null) ...[
                                const SizedBox(height: 10),
                                Text(translation,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        color: LF.cyan,
                                        fontStyle: FontStyle.italic)),
                              ],
                            ])
                          : const Column(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.psychology_rounded,
                                  size: 44, color: LF.violet),
                              SizedBox(height: 10),
                              Text('Récite la ligne suivante dans ta tête,\npuis touche pour vérifier',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: LF.muted)),
                            ]),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: _revealed && !done
              ? Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LF.danger,
                        side: const BorderSide(color: LF.danger),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _answer(false),
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('À revoir'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GradientButton(
                      label: 'Je savais',
                      icon: Icons.check_rounded,
                      onPressed: () => _answer(true),
                    ),
                  ),
                ])
              : SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Révéler',
                    icon: Icons.visibility_rounded,
                    onPressed: done ? null : () => setState(() => _revealed = true),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Texte à trous
// ---------------------------------------------------------------------------

class ClozeMode extends StatefulWidget {
  final String songId;
  const ClozeMode({super.key, required this.songId});

  @override
  State<ClozeMode> createState() => _ClozeModeState();
}

class _ClozeModeState extends State<ClozeMode> {
  Song? _song;
  List<ClozeQuestion> _qs = [];
  int _i = 0;
  int _good = 0;
  String? _picked;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_song != null) return;
    _song = _songOf(context, widget.songId);
    if (_song != null) _qs = PracticeEngine(_song!).cloze();
  }

  void _pick(String choice) {
    if (_picked != null) return;
    final q = _qs[_i];
    final ok = choice == q.answer;
    setState(() {
      _picked = choice;
      if (ok) _good++;
    });
    _song!.bump(q.lineIndex, ok);
  }

  void _next() {
    if (_i + 1 >= _qs.length) {
      setState(() => _i++);
      _finishSession(context, _song!, _good, _qs.length);
      return;
    }
    setState(() {
      _i++;
      _picked = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;
    if (song == null || _qs.isEmpty) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Pas assez de mots pour cet exercice.')));
    }
    final done = _i >= _qs.length;
    final q = _qs[done ? _qs.length - 1 : _i];

    final spans = <InlineSpan>[];
    for (var t = 0; t < q.tokens.length; t++) {
      if (t > 0) spans.add(const TextSpan(text: ' '));
      if (t == q.blankToken) {
        final shown = _picked == null ? '______' : q.tokens[t];
        final ok = _picked == q.answer;
        spans.add(TextSpan(
          text: shown,
          style: TextStyle(
            color: _picked == null ? LF.violet : (ok ? LF.success : LF.danger),
            fontWeight: FontWeight.w900,
            decoration: _picked == null ? null : TextDecoration.underline,
          ),
        ));
      } else {
        spans.add(TextSpan(text: q.tokens[t]));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Texte à trous')),
      body: Column(children: [
        _SessionHeader(index: _i, total: _qs.length, score: _good),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text('Complète la ligne :', style: TextStyle(color: LF.muted)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: LF.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: LF.border),
                ),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700, height: 1.4),
                    children: spans,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (song.translations[q.lineIndex] != null) ...[
                const SizedBox(height: 10),
                Text(song.translations[q.lineIndex]!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: LF.cyan, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 24),
              for (final c in q.choices)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ChoiceButton(
                    label: c,
                    state: _picked == null
                        ? _ChoiceState.idle
                        : c == q.answer
                            ? _ChoiceState.correct
                            : c == _picked
                                ? _ChoiceState.wrong
                                : _ChoiceState.dimmed,
                    onTap: () => _pick(c),
                  ),
                ),
            ],
          ),
        ),
        if (_picked != null && !done)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: SizedBox(
              width: double.infinity,
              child: GradientButton(
                  label: _i + 1 >= _qs.length ? 'Voir le résultat' : 'Suivant',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _next),
            ),
          ),
      ]),
    );
  }
}

enum _ChoiceState { idle, correct, wrong, dimmed }

class _ChoiceButton extends StatelessWidget {
  final String label;
  final _ChoiceState state;
  final VoidCallback onTap;
  const _ChoiceButton(
      {required this.label, required this.state, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      _ChoiceState.correct => LF.success,
      _ChoiceState.wrong => LF.danger,
      _ChoiceState.idle => LF.violet,
      _ChoiceState.dimmed => LF.border,
    };
    return Material(
      color: state == _ChoiceState.idle
          ? LF.surface2
          : color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 1.4),
          ),
          child: Row(children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: state == _ChoiceState.dimmed ? LF.muted : LF.text)),
            ),
            if (state == _ChoiceState.correct)
              const Icon(Icons.check_circle_rounded, color: LF.success),
            if (state == _ChoiceState.wrong)
              const Icon(Icons.cancel_rounded, color: LF.danger),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mémoire progressive
// ---------------------------------------------------------------------------

class MemoryMode extends StatefulWidget {
  final String songId;
  const MemoryMode({super.key, required this.songId});

  @override
  State<MemoryMode> createState() => _MemoryModeState();
}

class _MemoryModeState extends State<MemoryMode> {
  int _level = 1;
  final Set<String> _revealed = {};
  static const _labels = [
    'Tout visible',
    '1 mot sur 3 caché',
    '2 mots sur 3 cachés',
    'Initiales seulement',
    'Tout caché',
  ];

  @override
  Widget build(BuildContext context) {
    final song = _songOf(context, widget.songId);
    if (song == null) return const Scaffold();

    return Scaffold(
      appBar: AppBar(title: const Text('Mémoire progressive')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.visibility_rounded, color: LF.muted, size: 18),
              Expanded(
                child: Slider(
                  value: _level.toDouble(),
                  min: 0,
                  max: 4,
                  divisions: 4,
                  label: _labels[_level],
                  onChanged: (v) => setState(() {
                    _level = v.round();
                    _revealed.clear();
                  }),
                ),
              ),
              const Icon(Icons.visibility_off_rounded,
                  color: LF.muted, size: 18),
            ]),
            Text('Niveau $_level · ${_labels[_level]}',
                style: const TextStyle(
                    color: LF.cyan, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Touche un mot caché pour le révéler.',
                style: TextStyle(color: LF.muted, fontSize: 12.5)),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            itemCount: song.lines.length,
            itemBuilder: (_, i) {
              final line = song.lines[i];
              if (line.isBreak) return const SizedBox(height: 18);
              final tokens = line.text.split(RegExp(r'\s+'));
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Wrap(spacing: 6, runSpacing: 4, children: [
                  for (var t = 0; t < tokens.length; t++)
                    _word(i, t, tokens[t]),
                ]),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: _level < 4 ? 'Niveau suivant' : 'J\'ai tout récité !',
              icon: _level < 4 ? Icons.trending_up_rounded : Icons.emoji_events_rounded,
              onPressed: () async {
                if (_level < 4) {
                  setState(() {
                    _level++;
                    _revealed.clear();
                  });
                  return;
                }
                // Récitation complète : toutes les lignes progressent.
                for (final idx in song.textIndexes) {
                  song.bump(idx, true);
                }
                final total = song.textIndexes.length;
                await _finishSession(context, song, total, total);
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _word(int line, int token, String word) {
    final key = '$line:$token';
    final hidden = PracticeEngine.isHidden(line, token, _level) &&
        !_revealed.contains(key);
    if (!hidden) {
      return Text(word,
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _revealed.contains(key) ? LF.gold : LF.text));
    }
    return GestureDetector(
      onTap: () => setState(() => _revealed.add(key)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: LF.violet.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(PracticeEngine.maskWord(word, _level),
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: LF.violet,
                letterSpacing: 1)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Remets dans l'ordre
// ---------------------------------------------------------------------------

class OrderMode extends StatefulWidget {
  final String songId;
  const OrderMode({super.key, required this.songId});

  @override
  State<OrderMode> createState() => _OrderModeState();
}

class _OrderModeState extends State<OrderMode> {
  Song? _song;
  List<OrderQuestion> _qs = [];
  int _i = 0;
  int _good = 0;
  final List<int> _chosen = [];
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_song != null) return;
    _song = _songOf(context, widget.songId);
    if (_song != null) _qs = PracticeEngine(_song!).order();
  }

  bool _isCorrectFor(OrderQuestion q) {
    if (_chosen.length != q.correct.length) return false;
    for (var k = 0; k < _chosen.length; k++) {
      if (_song!.lines[_chosen[k]].text != _song!.lines[q.correct[k]].text) {
        return false;
      }
    }
    return true;
  }

  void _check() {
    final ok = _isCorrectFor(_qs[_i]);
    setState(() {
      _checked = true;
      if (ok) _good++;
    });
    for (final idx in _qs[_i].correct) {
      _song!.bump(idx, ok);
    }
  }

  void _next() {
    if (_i + 1 >= _qs.length) {
      setState(() => _i++);
      _finishSession(context, _song!, _good, _qs.length);
      return;
    }
    setState(() {
      _i++;
      _chosen.clear();
      _checked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final song = _song;
    if (song == null || _qs.isEmpty) {
      return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('Pas assez de lignes pour cet exercice.')));
    }
    final done = _i >= _qs.length;
    final q = _qs[done ? _qs.length - 1 : _i];
    final remaining = q.shuffled.where((x) => !_chosen.contains(x)).toList();
    final ok = _checked && _isCorrectFor(q);

    return Scaffold(
      appBar: AppBar(title: const Text('Remets dans l\'ordre')),
      body: Column(children: [
        _SessionHeader(index: _i, total: _qs.length, score: _good),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              const Text('Touche les lignes dans le bon ordre :',
                  style: TextStyle(color: LF.muted)),
              const SizedBox(height: 12),
              for (var k = 0; k < q.correct.length; k++)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(minHeight: 52),
                  decoration: BoxDecoration(
                    color: LF.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: !_checked
                          ? LF.border
                          : (k < _chosen.length &&
                                  song.lines[_chosen[k]].text ==
                                      song.lines[q.correct[k]].text)
                              ? LF.success
                              : LF.danger,
                    ),
                  ),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 13,
                      backgroundColor: LF.violet.withValues(alpha: 0.3),
                      child: Text('${k + 1}',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: k < _chosen.length
                          ? GestureDetector(
                              onTap: _checked
                                  ? null
                                  : () => setState(() => _chosen.removeAt(k)),
                              child: Text(song.lines[_chosen[k]].text,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            )
                          : const Text('…', style: TextStyle(color: LF.muted)),
                    ),
                  ]),
                ),
              if (_checked && !ok) ...[
                const SizedBox(height: 8),
                const Text('Le bon ordre :',
                    style: TextStyle(color: LF.cyan, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final idx in q.correct)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• ${song.lines[idx].text}',
                        style: const TextStyle(color: LF.muted)),
                  ),
              ],
              const SizedBox(height: 16),
              if (!_checked)
                for (final idx in remaining)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ChoiceButton(
                      label: song.lines[idx].text,
                      state: _ChoiceState.idle,
                      onTap: () => setState(() => _chosen.add(idx)),
                    ),
                  ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          child: SizedBox(
            width: double.infinity,
            child: done
                ? const SizedBox.shrink()
                : !_checked
                    ? GradientButton(
                        label: 'Vérifier',
                        icon: Icons.check_rounded,
                        onPressed:
                            _chosen.length == q.correct.length ? _check : null,
                      )
                    : GradientButton(
                        label: ok ? 'Parfait ! Suivant' : 'Suivant',
                        icon: Icons.arrow_forward_rounded,
                        onPressed: _next,
                      ),
          ),
        ),
      ]),
    );
  }
}
