/// Une ligne de paroles, éventuellement horodatée.
class LyricLine {
  final Duration? time;
  final String text;

  const LyricLine(this.time, this.text);

  bool get isBreak => text.trim().isEmpty;

  LyricLine withTime(Duration? t) => LyricLine(t, text);

  Map<String, dynamic> toJson() => {'t': time?.inMilliseconds, 'x': text};

  factory LyricLine.fromJson(Map<String, dynamic> j) => LyricLine(
        j['t'] == null ? null : Duration(milliseconds: (j['t'] as num).toInt()),
        (j['x'] ?? '') as String,
      );
}

/// Une chanson de la bibliothèque, avec sa progression d'apprentissage.
class Song {
  final String id;
  String title;
  String artist;
  String album;
  Duration? duration;
  List<LyricLine> lines;
  String language;
  String? audioPath;
  int syncOffsetMs;

  /// Traductions par index de ligne.
  Map<int, String> translations;
  String? translationLang;

  /// Notes / signification par index de ligne.
  Map<int, String> notes;

  /// Niveau de maîtrise par index de ligne (0 à 5).
  Map<int, int> mastery;

  DateTime addedAt;
  DateTime? lastOpened;
  DateTime? lastPracticed;
  int practiceSessions;
  bool favorite;

  static const int maxLevel = 5;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    this.duration,
    required this.lines,
    this.language = 'en',
    this.audioPath,
    this.syncOffsetMs = 0,
    Map<int, String>? translations,
    this.translationLang,
    Map<int, String>? notes,
    Map<int, int>? mastery,
    DateTime? addedAt,
    this.lastOpened,
    this.lastPracticed,
    this.practiceSessions = 0,
    this.favorite = false,
  })  : translations = translations ?? {},
        notes = notes ?? {},
        mastery = mastery ?? {},
        addedAt = addedAt ?? DateTime.now();

  bool get isSynced => lines.any((l) => l.time != null);

  /// Index des lignes qui contiennent du texte.
  List<int> get textIndexes => [
        for (var i = 0; i < lines.length; i++)
          if (!lines[i].isBreak) i
      ];

  int levelOf(int index) => mastery[index] ?? 0;

  /// Progression globale entre 0 et 1.
  double get progress {
    final idx = textIndexes;
    if (idx.isEmpty) return 0;
    var sum = 0;
    for (final i in idx) {
      sum += levelOf(i).clamp(0, maxLevel);
    }
    return sum / (idx.length * maxLevel);
  }

  int get masteredLines =>
      textIndexes.where((i) => levelOf(i) >= maxLevel - 1).length;

  void bump(int index, bool success) {
    final current = levelOf(index);
    mastery[index] =
        success ? (current + 1).clamp(0, maxLevel) : (current - 1).clamp(0, maxLevel);
  }

  /// Durée totale estimée (pour le mode chrono sans audio).
  Duration get estimatedDuration {
    if (duration != null && duration! > Duration.zero) return duration!;
    Duration last = Duration.zero;
    for (final l in lines) {
      if (l.time != null && l.time! > last) last = l.time!;
    }
    if (last == Duration.zero) {
      return Duration(seconds: (lines.length * 4).clamp(30, 600));
    }
    return last + const Duration(seconds: 6);
  }

  static Map<String, dynamic> _intKeyMap(Map<int, dynamic> m) =>
      m.map((k, v) => MapEntry(k.toString(), v));

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'duration': duration?.inMilliseconds,
        'lines': lines.map((l) => l.toJson()).toList(),
        'language': language,
        'audioPath': audioPath,
        'syncOffsetMs': syncOffsetMs,
        'translations': _intKeyMap(translations),
        'translationLang': translationLang,
        'notes': _intKeyMap(notes),
        'mastery': _intKeyMap(mastery),
        'addedAt': addedAt.toIso8601String(),
        'lastOpened': lastOpened?.toIso8601String(),
        'lastPracticed': lastPracticed?.toIso8601String(),
        'practiceSessions': practiceSessions,
        'favorite': favorite,
      };

  static Map<int, T> _readIntMap<T>(dynamic raw, T Function(dynamic) conv) {
    final out = <int, T>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        final key = int.tryParse(k.toString());
        if (key != null && v != null) out[key] = conv(v);
      });
    }
    return out;
  }

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        artist: (j['artist'] ?? '') as String,
        album: (j['album'] ?? '') as String,
        duration: j['duration'] == null
            ? null
            : Duration(milliseconds: (j['duration'] as num).toInt()),
        lines: ((j['lines'] as List?) ?? [])
            .map((e) => LyricLine.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        language: (j['language'] ?? 'en') as String,
        audioPath: j['audioPath'] as String?,
        syncOffsetMs: ((j['syncOffsetMs'] ?? 0) as num).toInt(),
        translations: _readIntMap<String>(j['translations'], (v) => v.toString()),
        translationLang: j['translationLang'] as String?,
        notes: _readIntMap<String>(j['notes'], (v) => v.toString()),
        mastery: _readIntMap<int>(j['mastery'], (v) => (v as num).toInt()),
        addedAt: _date(j['addedAt']) ?? DateTime.now(),
        lastOpened: _date(j['lastOpened']),
        lastPracticed: _date(j['lastPracticed']),
        practiceSessions: ((j['practiceSessions'] ?? 0) as num).toInt(),
        favorite: (j['favorite'] ?? false) as bool,
      );
}
