import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Traduction ligne par ligne via l'API gratuite MyMemory.
class TranslationService {
  final http.Client _client;
  TranslationService([http.Client? client]) : _client = client ?? http.Client();

  Future<String> translate(String text, String from, String to) async {
    final t = text.trim();
    if (t.isEmpty || from == to) return t;
    final uri = Uri.parse('https://api.mymemory.translated.net/get').replace(
      queryParameters: {'q': t, 'langpair': '$from|$to'},
    );
    final res = await _client.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception('Traduction indisponible (${res.statusCode})');
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    final status = data is Map ? data['responseStatus'] : null;
    final out = data is Map ? (data['responseData']?['translatedText']) : null;
    if (out is! String || out.isEmpty) {
      throw Exception('Traduction indisponible');
    }
    if (status != null && status.toString() != '200') {
      // Quota dépassé ou langue non prise en charge.
      throw Exception(out);
    }
    return _unescape(out);
  }

  static String _unescape(String s) => s
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');

  /// Traduit plusieurs lignes (4 requêtes en parallèle maximum).
  /// [onLine] est appelé dès qu'une ligne est traduite.
  Future<int> translateLines(
    Map<int, String> lines,
    String from,
    String to, {
    required void Function(int index, String translation) onLine,
  }) async {
    final queue = lines.entries.toList();
    var done = 0;
    Object? lastError;

    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final e = queue.removeAt(0);
        try {
          final tr = await translate(e.value, from, to);
          onLine(e.key, tr);
          done++;
        } catch (err) {
          lastError = err;
        }
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
    if (done == 0 && lastError != null) throw lastError!;
    return done;
  }
}
