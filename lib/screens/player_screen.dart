import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/audio_files.dart';
import '../services/language.dart';
import '../services/library_store.dart';
import '../services/lrc_parser.dart';
import '../services/playback.dart';
import '../services/translation_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'practice_screen.dart';
import 'sync_screen.dart';

class PlayerScreen extends StatefulWidget {
  final String songId;
  const PlayerScreen({super.key, required this.songId});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late LibraryStore _store;
  late Song _song;
  late LyricPlayback _pb;
  final _scroll = ScrollController();
  final Map<int, GlobalKey> _keys = {};
  int _active = -1;
  bool _showTranslation = false;
  bool _translating = false;
  int _translatedCount = 0;
  bool _autoScroll = true;
  bool _ready = false;

  // Boucle A-B par lignes
  int? _loopA;
  int? _loopB;

  static const _speeds = [0.5, 0.75, 1.0, 1.25];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _store = LibraryScope.read(context);
    _song = _store.byId(widget.songId)!;
    _pb = LyricPlayback(total: _song.estimatedDuration)..addListener(_onTick);
    _showTranslation = _song.translations.isNotEmpty;
    _ready = true;
    _restoreAudio();
  }

  Future<void> _restoreAudio() async {
    final path = _song.audioPath;
    if (path == null) return;
    final ok = await _pb.attachAudio(path);
    if (!ok && mounted) {
      _song.audioPath = null;
      _store.update(_song);
      _snack('Le fichier audio n\'est plus disponible. Ajoute-le à nouveau.');
    }
  }

  @override
  void dispose() {
    _pb.removeListener(_onTick);
    _pb.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Duration get _lyricPos =>
      _pb.position + Duration(milliseconds: _song.syncOffsetMs);

  void _onTick() {
    if (!_song.isSynced) {
      setState(() {});
      return;
    }
    final idx = LyricTimeline.activeIndex(_song.lines, _lyricPos);
    if (idx != _active) {
      _active = idx;
      if (_autoScroll && idx >= 0) _scrollTo(idx);
    }
    setState(() {});
  }

  void _scrollTo(int idx) {
    final ctx = _keys[idx]?.currentContext;
    if (ctx == null) {
      // Ligne hors écran (pas encore construite) : estimation.
      if (_scroll.hasClients) {
        final target = (idx * 64.0 - 200)
            .clamp(0.0, _scroll.position.maxScrollExtent);
        _scroll.animateTo(target,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic);
      }
      return;
    }
    Scrollable.ensureVisible(ctx,
        alignment: 0.38,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic);
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- Audio ----------

  Future<void> _pickAudio() async {
    try {
      final path = await pickAndStoreAudio(_song.id);
      if (path == null) return;
      final ok = await _pb.attachAudio(path);
      if (!ok) {
        _snack('Ce fichier audio ne peut pas être lu.');
        return;
      }
      _song.audioPath = path;
      await _store.update(_song);
      _snack('Audio ajouté. Lance la lecture !');
    } catch (e) {
      _snack('Impossible d\'ouvrir le fichier audio.');
    }
  }

  // ---------- Traduction ----------

  String get _defaultTarget => _song.language == 'fr' ? 'en' : 'fr';

  Future<void> _chooseTranslation() async {
    final target = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Traduire en…',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            for (final l in supportedLanguages)
              if (l.code != _song.language)
                ListTile(
                  leading: Text(l.flag, style: const TextStyle(fontSize: 22)),
                  title: Text(l.name),
                  trailing: _song.translationLang == l.code
                      ? const Icon(Icons.check_rounded, color: LF.cyan)
                      : null,
                  onTap: () => Navigator.pop(ctx, l.code),
                ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.record_voice_over_rounded),
              title: Text(
                  'Langue de la chanson : ${languageOf(_song.language).name}'),
              subtitle: const Text('Appuie pour corriger'),
              onTap: () => Navigator.pop(ctx, '__source'),
            ),
          ],
        ),
      ),
    );
    if (target == null) return;
    if (target == '__source') {
      await _chooseSourceLanguage();
      return;
    }
    await _translate(target);
  }

  Future<void> _chooseSourceLanguage() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final l in supportedLanguages)
            ListTile(
              leading: Text(l.flag, style: const TextStyle(fontSize: 22)),
              title: Text(l.name),
              trailing: _song.language == l.code
                  ? const Icon(Icons.check_rounded, color: LF.cyan)
                  : null,
              onTap: () => Navigator.pop(ctx, l.code),
            ),
        ]),
      ),
    );
    if (code == null || code == _song.language) return;
    setState(() {
      _song.language = code;
      _song.translations.clear();
      _song.translationLang = null;
      _showTranslation = false;
    });
    await _store.update(_song);
  }

  Future<void> _toggleTranslation() async {
    if (_showTranslation) {
      setState(() => _showTranslation = false);
      return;
    }
    if (_song.translations.isNotEmpty) {
      setState(() => _showTranslation = true);
      return;
    }
    await _translate(_defaultTarget);
  }

  Future<void> _translate(String target) async {
    if (_translating) return;
    if (_song.translationLang != target) {
      _song.translations.clear();
    }
    final todo = <int, String>{};
    for (final i in _song.textIndexes) {
      if (!_song.translations.containsKey(i)) todo[i] = _song.lines[i].text;
    }
    setState(() {
      _translating = true;
      _showTranslation = true;
      _translatedCount = 0;
      _song.translationLang = target;
    });
    try {
      await TranslationService().translateLines(
        todo,
        _song.language,
        target,
        onLine: (i, tr) {
          if (!mounted) return;
          setState(() {
            _song.translations[i] = tr;
            _translatedCount++;
          });
        },
      );
      await _store.update(_song);
    } catch (e) {
      _snack('Traduction indisponible pour le moment (connexion ou quota).');
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  // ---------- Lignes ----------

  Duration _lineStart(int i) =>
      (_song.lines[i].time ?? Duration.zero) -
      Duration(milliseconds: _song.syncOffsetMs);

  Duration _lineEnd(int i) =>
      LyricTimeline.endOf(_song.lines, i, _pb.total) -
      Duration(milliseconds: _song.syncOffsetMs);

  void _seekLine(int i) {
    if (!_song.isSynced || _song.lines[i].time == null) return;
    _pb.seek(_lineStart(i));
    if (!_pb.playing) _pb.play();
    setState(() => _autoScroll = true);
  }

  void _loopLines(int a, int b) {
    if (!_song.isSynced) return;
    final start = _lineStart(a);
    final end = _lineEnd(b);
    _loopA = a;
    _loopB = b;
    _pb.setLoop(start, end);
    _pb.seek(start);
    if (!_pb.playing) _pb.play();
    _snack(a == b
        ? 'Boucle sur la ligne ${a + 1}'
        : 'Boucle des lignes ${a + 1} à ${b + 1}');
  }

  void _clearLoop() {
    _loopA = null;
    _loopB = null;
    _pb.clearLoop();
  }

  int _endOfPassage(int i) {
    // Jusqu'à la prochaine pause (ligne vide) ou 4 lignes max.
    var end = i;
    for (var k = i + 1; k < _song.lines.length && k <= i + 3; k++) {
      if (_song.lines[k].isBreak) break;
      end = k;
    }
    return end;
  }

  Future<void> _lineMenu(int i) async {
    final line = _song.lines[i];
    if (line.isBreak) return;
    final level = _song.levelOf(i);
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            child: Column(children: [
              Text(line.text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              if (_song.translations[i] != null) ...[
                const SizedBox(height: 6),
                Text(_song.translations[i]!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: LF.cyan, fontStyle: FontStyle.italic)),
              ],
              const SizedBox(height: 8),
              Text('Maîtrise : $level/${Song.maxLevel}',
                  style: const TextStyle(color: LF.muted, fontSize: 12.5)),
            ]),
          ),
          if (_song.isSynced) ...[
            ListTile(
              leading: const Icon(Icons.repeat_one_rounded, color: LF.cyan),
              title: const Text('Répéter cette ligne'),
              onTap: () {
                Navigator.pop(ctx);
                _loopLines(i, i);
              },
            ),
            ListTile(
              leading: const Icon(Icons.repeat_rounded, color: LF.cyan),
              title: const Text('Répéter ce passage'),
              subtitle: const Text('Jusqu\'à la fin du couplet (4 lignes max)'),
              onTap: () {
                Navigator.pop(ctx);
                _loopLines(i, _endOfPassage(i));
              },
            ),
            ListTile(
              leading: const Icon(Icons.start_rounded, color: LF.violet),
              title: Text(_loopA != null && _loopB == null
                  ? 'Fin de boucle ici (B)'
                  : 'Début de boucle ici (A)'),
              onTap: () {
                Navigator.pop(ctx);
                if (_loopA != null && _loopB == null && i >= _loopA!) {
                  _loopLines(_loopA!, i);
                } else {
                  _clearLoop();
                  setState(() => _loopA = i);
                  _snack('Point A placé. Choisis maintenant la ligne de fin (B).');
                }
              },
            ),
          ],
          ListTile(
            leading: const Icon(Icons.sticky_note_2_outlined, color: LF.gold),
            title: Text(_song.notes[i] == null
                ? 'Ajouter une note / signification'
                : 'Modifier la note'),
            onTap: () {
              Navigator.pop(ctx);
              _editNote(i);
            },
          ),
          ListTile(
            leading: const Icon(Icons.verified_rounded, color: LF.success),
            title: const Text('Je connais cette ligne'),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _song.mastery[i] = Song.maxLevel);
              _store.update(_song);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _editNote(int i) async {
    final ctrl = TextEditingController(text: _song.notes[i] ?? '');
    final res = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LF.surface,
        title: const Text('Note / signification'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(
              hintText: 'Ex. : expression qui veut dire « laisse tomber »'),
        ),
        actions: [
          if (_song.notes[i] != null)
            TextButton(
                onPressed: () => Navigator.pop(ctx, ''),
                child: const Text('Supprimer',
                    style: TextStyle(color: LF.danger))),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Enregistrer')),
        ],
      ),
    );
    ctrl.dispose();
    if (res == null) return;
    setState(() {
      if (res.trim().isEmpty) {
        _song.notes.remove(i);
      } else {
        _song.notes[i] = res.trim();
      }
    });
    await _store.update(_song);
  }

  void _adjustOffset(int deltaMs) {
    setState(() => _song.syncOffsetMs += deltaMs);
    _store.update(_song);
  }

  Future<void> _openSync() async {
    await _pb.pause();
    if (!mounted) return;
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => SyncScreen(songId: _song.id)));
    if (!mounted) return;
    // La synchro a pu changer les temps ou l'audio.
    if (_song.audioPath != null && !_pb.hasAudio) await _restoreAudio();
    setState(() => _active = -1);
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final synced = _song.isSynced;
    return Scaffold(
      appBar: AppBar(
        title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(_song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(_song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: LF.muted)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Traduction',
            onPressed: _toggleTranslation,
            icon: Icon(Icons.translate_rounded,
                color: _showTranslation ? LF.cyan : LF.text),
          ),
          IconButton(
            tooltip: 'S\'entraîner',
            onPressed: () async {
              await _pb.pause();
              if (!context.mounted) return;
              await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PracticeScreen(songId: _song.id)));
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.school_rounded),
          ),
          PopupMenuButton<String>(
            color: LF.surface2,
            onSelected: (v) {
              switch (v) {
                case 'audio':
                  _pickAudio();
                  break;
                case 'lang':
                  _chooseTranslation();
                  break;
                case 'sync':
                  _openSync();
                  break;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'audio',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.audio_file_rounded),
                  title: Text(_pb.hasAudio
                      ? 'Changer le fichier audio'
                      : 'Ajouter le fichier audio'),
                ),
              ),
              const PopupMenuItem(
                value: 'lang',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.language_rounded),
                  title: Text('Langue de traduction'),
                ),
              ),
              PopupMenuItem(
                value: 'sync',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.touch_app_rounded),
                  title: Text(synced ? 'Resynchroniser' : 'Synchroniser'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A0B3A), LF.bg, Color(0xFF071233)],
          ),
        ),
        child: SafeArea(
          child: Column(children: [
            if (_translating)
              LinearProgressIndicator(
                value: _song.textIndexes.isEmpty
                    ? null
                    : (_translatedCount / _song.textIndexes.length)
                        .clamp(0.0, 1.0),
                minHeight: 2,
                color: LF.cyan,
                backgroundColor: Colors.transparent,
              ),
            if (!synced) _UnsyncedBanner(onSync: _openSync),
            if (!_pb.hasAudio && synced)
              _InfoBar(
                icon: Icons.timer_outlined,
                text: 'Mode chrono : les paroles défilent sans son. '
                    'Ajoute ton fichier audio pour chanter dessus.',
                action: 'Ajouter',
                onAction: _pickAudio,
              ),
            Expanded(
              child: NotificationListener<UserScrollNotification>(
                onNotification: (n) {
                  if (_autoScroll && _pb.playing) {
                    setState(() => _autoScroll = false);
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 160),
                  itemCount: _song.lines.length,
                  itemBuilder: (_, i) => _buildLine(i),
                ),
              ),
            ),
            _controls(),
          ]),
        ),
      ),
      floatingActionButton: !_autoScroll && synced
          ? Padding(
              padding: const EdgeInsets.only(bottom: 170),
              child: FloatingActionButton.small(
                backgroundColor: LF.violet,
                onPressed: () {
                  setState(() => _autoScroll = true);
                  if (_active >= 0) _scrollTo(_active);
                },
                child: const Icon(Icons.my_location_rounded, color: Colors.white),
              ),
            )
          : null,
    );
  }

  Widget _buildLine(int i) {
    final line = _song.lines[i];
    final key = _keys.putIfAbsent(i, () => GlobalKey());
    final synced = _song.isSynced;
    final isActive = synced && i == _active;
    final isPast = synced && _active >= 0 && i < _active;
    final inLoop = _loopA != null &&
        i >= _loopA! &&
        i <= (_loopB ?? _loopA!);

    if (line.isBreak) {
      return Padding(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Align(
          alignment: Alignment.centerLeft,
          child: WaveBars(
            bars: 5,
            height: 18,
            barWidth: 3,
            animate: isActive && _pb.playing,
          ),
        ),
      );
    }

    final color = isActive
        ? Colors.white
        : isPast
            ? LF.muted.withValues(alpha: 0.55)
            : (synced ? LF.text.withValues(alpha: 0.6) : LF.text);
    final tr = _showTranslation ? _song.translations[i] : null;
    final note = _song.notes[i];
    final mastered = _song.levelOf(i) >= Song.maxLevel - 1;

    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: () => _seekLine(i),
      onLongPress: () => _lineMenu(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: inLoop ? LF.violet.withValues(alpha: 0.14) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: inLoop ? LF.violet : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: TextStyle(
              fontSize: isActive ? 26 : 22,
              height: 1.25,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
              color: color,
              shadows: isActive
                  ? [Shadow(color: LF.violet.withValues(alpha: 0.9), blurRadius: 18)]
                  : null,
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(line.text)),
              if (mastered)
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 4),
                  child: Icon(Icons.verified_rounded,
                      size: 16, color: LF.success),
                ),
            ]),
          ),
          if (tr != null) ...[
            const SizedBox(height: 4),
            Text(tr,
                style: TextStyle(
                    fontSize: isActive ? 16 : 14.5,
                    color: LF.cyan.withValues(alpha: isActive ? 1 : 0.7),
                    fontStyle: FontStyle.italic)),
          ],
          if (note != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.sticky_note_2_rounded, size: 14, color: LF.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(note,
                    style: const TextStyle(fontSize: 13, color: LF.gold)),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _controls() {
    final pos = _pb.position;
    final total = _pb.total;
    final maxMs = total.inMilliseconds.toDouble().clamp(1.0, double.infinity);
    final synced = _song.isSynced;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: LF.surface.withValues(alpha: 0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: const Border(top: BorderSide(color: LF.border)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text(formatDuration(pos),
              style: const TextStyle(fontSize: 12, color: LF.muted)),
          Expanded(
            child: Slider(
              value: pos.inMilliseconds.toDouble().clamp(0.0, maxMs),
              max: maxMs,
              onChanged: synced || _pb.hasAudio
                  ? (v) => _pb.seek(Duration(milliseconds: v.round()))
                  : null,
            ),
          ),
          Text(formatDuration(total),
              style: const TextStyle(fontSize: 12, color: LF.muted)),
        ]),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          // Vitesse
          PopupMenuButton<double>(
            tooltip: 'Vitesse',
            color: LF.surface2,
            initialValue: _pb.speed,
            onSelected: (v) => _pb.setSpeed(v),
            itemBuilder: (_) => [
              for (final s in _speeds)
                PopupMenuItem(value: s, child: Text('×$s')),
            ],
            child: Pill('×${_pb.speed}', color: LF.cyan, icon: Icons.speed_rounded),
          ),
          IconButton(
            onPressed: () => _pb.skip(const Duration(seconds: -5)),
            icon: const Icon(Icons.replay_5_rounded, size: 30),
          ),
          GestureDetector(
            onTap: (synced || _pb.hasAudio) ? _pb.toggle : _openSync,
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LF.gradient,
                boxShadow: [
                  BoxShadow(
                      color: LF.violet.withValues(alpha: 0.6), blurRadius: 22),
                ],
              ),
              child: Icon(
                _pb.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _pb.skip(const Duration(seconds: 5)),
            icon: const Icon(Icons.forward_5_rounded, size: 30),
          ),
          // Boucle
          GestureDetector(
            onTap: () {
              if (_pb.looping || _loopA != null) {
                setState(_clearLoop);
                _snack('Boucle désactivée');
              } else {
                _snack('Appui long sur une ligne pour la répéter en boucle.');
              }
            },
            child: Pill(
              _pb.looping ? 'Boucle' : (_loopA != null ? 'A…' : 'Boucle'),
              color: _pb.looping || _loopA != null ? LF.magenta : LF.muted,
              icon: _pb.looping ? Icons.repeat_on_rounded : Icons.repeat_rounded,
            ),
          ),
        ]),
        if (synced)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Décalage des paroles',
                  style: TextStyle(fontSize: 12, color: LF.muted)),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Paroles plus tard',
                onPressed: () => _adjustOffset(-200),
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
              ),
              Text(
                  '${_song.syncOffsetMs >= 0 ? '+' : ''}${(_song.syncOffsetMs / 1000).toStringAsFixed(1)} s',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Paroles plus tôt',
                onPressed: () => _adjustOffset(200),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
              ),
            ]),
          ),
      ]),
    );
  }
}

class _UnsyncedBanner extends StatelessWidget {
  final VoidCallback onSync;
  const _UnsyncedBanner({required this.onSync});

  @override
  Widget build(BuildContext context) {
    return _InfoBar(
      icon: Icons.notes_rounded,
      text: 'Paroles non synchronisées. Synchronise-les en tapant au rythme de la musique.',
      action: 'Synchroniser',
      onAction: onSync,
      color: LF.gold,
    );
  }
}

class _InfoBar extends StatelessWidget {
  final IconData icon;
  final String text;
  final String action;
  final VoidCallback onAction;
  final Color color;

  const _InfoBar({
    required this.icon,
    required this.text,
    required this.action,
    required this.onAction,
    this.color = LF.cyan,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 12.5)),
        ),
        TextButton(
          onPressed: onAction,
          child: Text(action, style: TextStyle(color: color)),
        ),
      ]),
    );
  }
}
