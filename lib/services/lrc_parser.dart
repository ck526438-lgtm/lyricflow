import '../models/song.dart';

/// Résultat d'analyse d'un fichier LRC ou de paroles brutes.
class ParsedLyrics {
  final List<LyricLine> lines;
  final String? title;
  final String? artist;
  final String? album;

  const ParsedLyrics(this.lines, {this.title, this.artist, this.album});

  bool get isSynced => lines.any((l) => l.time != null);
}

class LrcParser {
  static final RegExp _timeTag =
      RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');
  static final RegExp _metaTag = RegExp(r'^\[([a-zA-Z#]+):(.*)\]\s*$');
  static final RegExp _wordTag = RegExp(r'<\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?>');

  /// Vrai si le texte contient au moins une balise de temps LRC.
  static bool looksLikeLrc(String text) => _timeTag.hasMatch(text);

  /// Analyse du texte LRC ou brut (détection automatique).
  static ParsedLyrics parse(String text) =>
      looksLikeLrc(text) ? parseLrc(text) : ParsedLyrics(parsePlain(text));

  static Duration _toDuration(String min, String sec, String? frac) {
    var ms = 0;
    if (frac != null && frac.isNotEmpty) {
      ms = int.parse(frac.padRight(3, '0').substring(0, 3));
    }
    return Duration(
      minutes: int.parse(min),
      seconds: int.parse(sec),
      milliseconds: ms,
    );
  }

  static ParsedLyrics parseLrc(String text) {
    final out = <LyricLine>[];
    String? title, artist, album;
    var offset = 0;

    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      final matches = _timeTag.allMatches(line).toList();
      if (matches.isEmpty) {
        final meta = _metaTag.firstMatch(line);
        if (meta != null) {
          final key = meta.group(1)!.toLowerCase();
          final value = meta.group(2)!.trim();
          switch (key) {
            case 'ti':
              title = value;
              break;
            case 'ar':
              artist = value;
              break;
            case 'al':
              album = value;
              break;
            case 'offset':
              offset = int.tryParse(value) ?? 0;
              break;
          }
        }
        continue;
      }

      final lyric =
          line.substring(matches.last.end).replaceAll(_wordTag, '').trim();
      for (final m in matches) {
        var t = _toDuration(m.group(1)!, m.group(2)!, m.group(3));
        // Dans le format LRC, un offset positif avance les paroles.
        t -= Duration(milliseconds: offset);
        if (t < Duration.zero) t = Duration.zero;
        out.add(LyricLine(t, lyric));
      }
    }

    out.sort((a, b) => a.time!.compareTo(b.time!));
    return ParsedLyrics(out, title: title, artist: artist, album: album);
  }

  static List<LyricLine> parsePlain(String text) => text
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((l) => LyricLine(null, l))
      .toList();

  static String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final cs = ((d.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$cs';
  }

  /// Exporte des lignes au format LRC.
  static String toLrc(List<LyricLine> lines, {String? title, String? artist}) {
    final b = StringBuffer();
    if (title != null && title.isNotEmpty) b.writeln('[ti:$title]');
    if (artist != null && artist.isNotEmpty) b.writeln('[ar:$artist]');
    b.writeln('[re:LyricFlow]');
    for (final l in lines) {
      if (l.time == null) {
        b.writeln(l.text);
      } else {
        b.writeln('[${_fmt(l.time!)}]${l.text}');
      }
    }
    return b.toString();
  }
}

/// Outils de calcul sur la timeline des paroles.
class LyricTimeline {
  /// Index de la ligne active à [position] (ou -1 avant la première).
  static int activeIndex(List<LyricLine> lines, Duration position) {
    var lo = 0, hi = lines.length - 1, ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final t = lines[mid].time;
      if (t == null) return -1;
      if (t <= position) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans;
  }

  /// Fin de la ligne [index] (début de la ligne suivante ou [total]).
  static Duration endOf(List<LyricLine> lines, int index, Duration total) {
    for (var i = index + 1; i < lines.length; i++) {
      final t = lines[i].time;
      if (t != null && t > (lines[index].time ?? Duration.zero)) return t;
    }
    return total;
  }
}
