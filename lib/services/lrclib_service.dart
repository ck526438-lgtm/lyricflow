import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/song.dart';
import 'language.dart';
import 'lrc_parser.dart';

/// Un résultat de recherche LRCLIB.
class LyricsResult {
  final int id;
  final String title;
  final String artist;
  final String album;
  final Duration? duration;
  final bool instrumental;
  final String? plainLyrics;
  final String? syncedLyrics;

  const LyricsResult({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.instrumental,
    this.plainLyrics,
    this.syncedLyrics,
  });

  bool get hasSynced => (syncedLyrics ?? '').trim().isNotEmpty;
  bool get hasPlain => (plainLyrics ?? '').trim().isNotEmpty;
  bool get hasLyrics => hasSynced || hasPlain;

  factory LyricsResult.fromJson(Map<String, dynamic> j) => LyricsResult(
        id: (j['id'] as num).toInt(),
        title: (j['trackName'] ?? j['name'] ?? '') as String,
        artist: (j['artistName'] ?? '') as String,
        album: (j['albumName'] ?? '') as String,
        duration: j['duration'] is num
            ? Duration(milliseconds: ((j['duration'] as num) * 1000).round())
            : null,
        instrumental: (j['instrumental'] ?? false) as bool,
        plainLyrics: j['plainLyrics'] as String?,
        syncedLyrics: j['syncedLyrics'] as String?,
      );

  Song toSong() {
    final lines = hasSynced
        ? LrcParser.parseLrc(syncedLyrics!).lines
        : LrcParser.parsePlain(plainLyrics ?? '');
    final sample = lines.take(30).map((l) => l.text).join(' ');
    return Song(
      id: 'lrclib-$id',
      title: title,
      artist: artist,
      album: album,
      duration: duration,
      lines: lines,
      language: LanguageGuesser.guess(sample),
    );
  }
}

/// Client de l'API publique et gratuite LRCLIB (https://lrclib.net).
class LrclibService {
  static const _base = 'https://lrclib.net/api';
  static const _headers = {
    'User-Agent': 'LyricFlow v1.0.0 (https://github.com/ck526438-lgtm/lyricflow)',
    'Accept': 'application/json',
  };

  final http.Client _client;
  LrclibService([http.Client? client]) : _client = client ?? http.Client();

  Future<List<LyricsResult>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    final uri = Uri.parse('$_base/search').replace(queryParameters: {'q': q});
    final res = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Le serveur de paroles a répondu ${res.statusCode}');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List) return [];
    final results = data
        .whereType<Map>()
        .map((e) => LyricsResult.fromJson(Map<String, dynamic>.from(e)))
        .where((r) => r.hasLyrics)
        .toList();
    // Les paroles synchronisées d'abord.
    results.sort((a, b) {
      if (a.hasSynced == b.hasSynced) return 0;
      return a.hasSynced ? -1 : 1;
    });
    return results;
  }
}
