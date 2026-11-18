import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Horloge de lecture : soit un vrai fichier audio, soit un chrono
/// (pour suivre les paroles sans audio, à vitesse réglable).
class LyricPlayback extends ChangeNotifier {
  AudioPlayer? _player;
  final List<StreamSubscription> _subs = [];

  Duration _position = Duration.zero;
  Duration _total;
  bool _playing = false;
  double _speed = 1.0;

  // Chrono interne
  final Stopwatch _sw = Stopwatch();
  Duration _base = Duration.zero;
  Timer? _ticker;

  // Boucle A-B
  Duration? loopStart;
  Duration? loopEnd;

  bool _disposed = false;

  LyricPlayback({required Duration total}) : _total = total;

  bool get hasAudio => _player != null;
  bool get playing => _playing;
  double get speed => _speed;
  Duration get total => _total;
  bool get looping => loopStart != null && loopEnd != null;

  Duration get position {
    if (_player == null && _playing) {
      final p = _base + _sw.elapsed * _speed;
      return p > _total ? _total : p;
    }
    return _position;
  }

  /// Charge un fichier audio local. Retourne false si le fichier est illisible.
  Future<bool> attachAudio(String path) async {
    if (!File(path).existsSync()) return false;
    await _detachAudio();
    final player = AudioPlayer();
    try {
      final d = await player.setFilePath(path);
      if (d != null && d > Duration.zero) _total = d;
    } catch (_) {
      await player.dispose();
      return false;
    }
    _stopChrono();
    _player = player;
    await player.setSpeed(_speed);
    _subs.add(player.positionStream.listen((p) {
      _position = p;
      _checkLoop();
      _notify();
    }));
    _subs.add(player.playerStateStream.listen((s) {
      _playing = s.playing && s.processingState != ProcessingState.completed;
      if (s.processingState == ProcessingState.completed) {
        player.pause();
        player.seek(Duration.zero);
      }
      _notify();
    }));
    _subs.add(player.durationStream.listen((d) {
      if (d != null && d > Duration.zero) {
        _total = d;
        _notify();
      }
    }));
    _position = Duration.zero;
    _notify();
    return true;
  }

  Future<void> _detachAudio() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    final p = _player;
    _player = null;
    if (p != null) await p.dispose();
  }

  void _startChrono() {
    _base = _position;
    _sw
      ..reset()
      ..start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final p = position;
      if (p >= _total) {
        _position = _total;
        _stopChrono();
        _playing = false;
      }
      _checkLoop();
      _notify();
    });
  }

  void _stopChrono() {
    if (_sw.isRunning) {
      _position = _base + _sw.elapsed * _speed;
      if (_position > _total) _position = _total;
    }
    _sw
      ..stop()
      ..reset();
    _ticker?.cancel();
    _ticker = null;
  }

  void _checkLoop() {
    final s = loopStart, e = loopEnd;
    if (s == null || e == null) return;
    if (position >= e) seek(s);
  }

  Future<void> play() async {
    if (_player != null) {
      _player!.play();
      return;
    }
    if (_position >= _total) _position = Duration.zero;
    _playing = true;
    _startChrono();
    _notify();
  }

  Future<void> pause() async {
    if (_player != null) {
      await _player!.pause();
      return;
    }
    _stopChrono();
    _playing = false;
    _notify();
  }

  Future<void> toggle() => _playing ? pause() : play();

  Future<void> seek(Duration to) async {
    if (to < Duration.zero) to = Duration.zero;
    if (to > _total) to = _total;
    if (_player != null) {
      _position = to;
      await _player!.seek(to);
    } else {
      _position = to;
      if (_playing) _startChrono();
    }
    _notify();
  }

  Future<void> skip(Duration delta) => seek(position + delta);

  Future<void> setSpeed(double s) async {
    if (_player != null) {
      _speed = s;
      await _player!.setSpeed(s);
    } else {
      final wasPlaying = _playing;
      if (wasPlaying) _stopChrono();
      _speed = s;
      if (wasPlaying) _startChrono();
    }
    _notify();
  }

  void setLoop(Duration? start, Duration? end) {
    if (start != null && end != null && end <= start) {
      end = start + const Duration(seconds: 2);
    }
    loopStart = start;
    loopEnd = end;
    _notify();
  }

  void clearLoop() => setLoop(null, null);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }
}
