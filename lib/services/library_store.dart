import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

/// Bibliothèque personnelle : chansons + statistiques, stockées sur l'appareil.
class LibraryStore extends ChangeNotifier {
  static const _songsKey = 'lyricflow.songs.v1';
  static const _daysKey = 'lyricflow.practiceDays.v1';

  final List<Song> _songs = [];
  final Set<String> _practiceDays = {};
  SharedPreferences? _prefs;
  bool loaded = false;

  List<Song> get songs {
    final list = [..._songs];
    list.sort((a, b) {
      final da = a.lastOpened ?? a.addedAt;
      final db = b.lastOpened ?? b.addedAt;
      return db.compareTo(da);
    });
    return list;
  }

  Song? byId(String id) {
    for (final s in _songs) {
      if (s.id == id) return s;
    }
    return null;
  }

  bool contains(String id) => byId(id) != null;

  Song? get lastOpened {
    final list = songs.where((s) => s.lastOpened != null).toList();
    return list.isEmpty ? null : list.first;
  }

  int get totalSessions =>
      _songs.fold(0, (sum, s) => sum + s.practiceSessions);

  int get totalMasteredLines =>
      _songs.fold(0, (sum, s) => sum + s.masteredLines);

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Nombre de jours consécutifs d'entraînement (jusqu'à aujourd'hui ou hier).
  int get streak {
    var day = DateTime.now();
    if (!_practiceDays.contains(_dayKey(day))) {
      day = day.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (_practiceDays.contains(_dayKey(day))) {
      count++;
      day = day.subtract(const Duration(days: 1));
    }
    return count;
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_songsKey);
    _songs.clear();
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final e in list) {
          _songs.add(Song.fromJson(Map<String, dynamic>.from(e as Map)));
        }
      } catch (_) {
        // Données corrompues : on repart d'une bibliothèque vide.
      }
    }
    _practiceDays
      ..clear()
      ..addAll(_prefs!.getStringList(_daysKey) ?? const []);
    loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(
        _songsKey, jsonEncode(_songs.map((s) => s.toJson()).toList()));
    await prefs.setStringList(_daysKey, _practiceDays.toList());
  }

  Future<Song> add(Song song) async {
    final existing = byId(song.id);
    if (existing != null) return existing;
    _songs.add(song);
    notifyListeners();
    await _save();
    return song;
  }

  /// À appeler après toute modification d'une chanson.
  Future<void> update(Song song) async {
    if (!contains(song.id)) _songs.add(song);
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    _songs.removeWhere((s) => s.id == id);
    notifyListeners();
    await _save();
  }

  Future<void> markOpened(Song song) async {
    song.lastOpened = DateTime.now();
    await update(song);
  }

  Future<void> recordPractice(Song song) async {
    song.practiceSessions++;
    song.lastPracticed = DateTime.now();
    _practiceDays.add(_dayKey(DateTime.now()));
    await update(song);
  }
}

/// Donne accès à la bibliothèque partout dans l'arbre de widgets.
class LibraryScope extends InheritedNotifier<LibraryStore> {
  const LibraryScope({super.key, required LibraryStore store, required super.child})
      : super(notifier: store);

  static LibraryStore of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LibraryScope>()!.notifier!;

  static LibraryStore read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LibraryScope>()!.notifier!;
}
