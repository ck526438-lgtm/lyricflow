import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/audio_files.dart';
import '../services/library_store.dart';
import '../services/playback.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Synchronisation manuelle : on tape au début de chaque ligne.
class SyncScreen extends StatefulWidget {
  final String songId;
  const SyncScreen({super.key, required this.songId});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  late LibraryStore _store;
  late Song _song;
  late LyricPlayback _pb;
  late List<Duration?> _times;
  final _scroll = ScrollController();
  int _cursor = 0;
  bool _started = false;
  bool _ready = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ready) return;
    _store = LibraryScope.read(context);
    _song = _store.byId(widget.songId)!;
    final total = Duration(
        seconds: (_song.lines.length * 8).clamp(60, 1200));
    _pb = LyricPlayback(total: total)..addListener(_tick);
    _times = List<Duration?>.filled(_song.lines.length, null);
    _ready = true;
    if (_song.audioPath != null) _pb.attachAudio(_song.audioPath!);
  }

  void _tick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pb.removeListener(_tick);
    _pb.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    try {
      final path = await pickAndStoreAudio(_song.id);
      if (path == null) return;
      final ok = await _pb.attachAudio(path);
      if (!ok) return;
      _song.audioPath = path;
      await _store.update(_song);
      if (mounted) setState(() {});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le fichier audio.')));
    }
  }

  Future<void> _start() async {
    setState(() {
      _times = List<Duration?>.filled(_song.lines.length, null);
      _cursor = 0;
      _started = true;
    });
    await _pb.seek(Duration.zero);
    await _pb.play();
  }

  void _tap() {
    if (!_started) {
      _start();
      return;
    }
    if (_cursor >= _song.lines.length) return;
    setState(() {
      _times[_cursor] = _pb.position;
      _cursor++;
    });
    _follow();
    if (_cursor >= _song.lines.length) _finish();
  }

  void _undo() {
    if (_cursor == 0) return;
    setState(() {
      _cursor--;
      _times[_cursor] = null;
    });
    final back = _cursor > 0 ? _times[_cursor - 1] : Duration.zero;
    _pb.seek(back ?? Duration.zero);
    _follow();
  }

  void _follow() {
    if (!_scroll.hasClients) return;
    final target =
        (_cursor * 58.0 - 160).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _finish() async {
    await _pb.pause();
    if (_cursor == 0) {
      if (mounted) Navigator.pop(context);
      return;
    }
    // Lignes non tapées : espacées de 3 s après la dernière.
    var last = _times[_cursor - 1] ?? Duration.zero;
    final lines = <LyricLine>[];
    for (var i = 0; i < _song.lines.length; i++) {
      var t = _times[i];
      if (t == null) {
        last += const Duration(seconds: 3);
        t = last;
      } else if (i > 0 && lines.isNotEmpty && t < lines.last.time!) {
        t = lines.last.time!;
      }
      lines.add(_song.lines[i].withTime(t));
    }
    _song.lines = lines;
    _song.syncOffsetMs = 0;
    if (!_pb.hasAudio) {
      _song.duration = last + const Duration(seconds: 4);
    }
    await _store.update(_song);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paroles synchronisées ✔')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final done = _cursor >= _song.lines.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Synchroniser'),
        actions: [
          if (_started && _cursor > 0)
            TextButton(onPressed: _finish, child: const Text('Terminer')),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Text(
            _started
                ? 'Tape le gros bouton au moment exact où chaque ligne commence.'
                : _pb.hasAudio
                    ? 'Lance la musique, puis tape au début de chaque ligne.'
                    : 'Sans fichier audio, le chrono démarre : chante dans ta tête et tape à chaque ligne. '
                        'Pour plus de précision, ajoute le fichier audio.',
            style: const TextStyle(color: LF.muted, fontSize: 13),
          ),
        ),
        if (!_pb.hasAudio)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton.icon(
              onPressed: _pickAudio,
              icon: const Icon(Icons.audio_file_rounded),
              label: const Text('Ajouter le fichier audio'),
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            itemCount: _song.lines.length,
            itemBuilder: (_, i) {
              final line = _song.lines[i];
              final isNext = i == _cursor && _started;
              final t = _times[i];
              return Container(
                height: 50,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isNext ? LF.violet.withValues(alpha: 0.2) : LF.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isNext ? LF.violet : LF.border),
                ),
                child: Row(children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      t == null ? '--:--' : formatDuration(t),
                      style: TextStyle(
                          fontSize: 12,
                          color: t == null ? LF.muted : LF.cyan,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line.isBreak ? '♪ (pause)' : line.text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: isNext ? FontWeight.w800 : FontWeight.w500,
                        color: t != null ? LF.muted : LF.text,
                      ),
                    ),
                  ),
                ]),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          decoration: const BoxDecoration(
            color: LF.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Text(formatDuration(_pb.position),
                    style: const TextStyle(color: LF.muted)),
                const Spacer(),
                Text('${_cursor.clamp(0, _song.lines.length)}/${_song.lines.length} lignes',
                    style: const TextStyle(color: LF.muted)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                IconButton.filledTonal(
                  onPressed: _cursor > 0 ? _undo : null,
                  icon: const Icon(Icons.undo_rounded),
                  tooltip: 'Annuler la dernière ligne',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 64,
                    child: GradientButton(
                      label: !_started
                          ? 'Démarrer'
                          : done
                              ? 'Terminé'
                              : 'TAP — ligne ${_cursor + 1}',
                      icon: !_started
                          ? Icons.play_arrow_rounded
                          : Icons.touch_app_rounded,
                      onPressed: done ? null : _tap,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  onPressed: _started ? _pb.toggle : null,
                  icon: Icon(_pb.playing
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded),
                  tooltip: 'Pause',
                ),
              ]),
              if (_started) ...[
                const SizedBox(height: 10),
                const WaveBars(height: 22, bars: 9, barWidth: 3),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
