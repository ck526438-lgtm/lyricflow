import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/language.dart';
import '../services/library_store.dart';
import '../services/lrc_parser.dart';
import '../services/lrclib_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  final _service = LrclibService();
  List<LyricsResult> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _service.search(q);
      if (!mounted) return;
      setState(() {
        _results = r;
        _searched = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error =
          'Impossible de joindre le serveur de paroles. Vérifie ta connexion.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _preview(LyricsResult r) {
    final song = r.toSong();
    final store = LibraryScope.read(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              SongArt(song: song, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(song.title,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(song.artist, style: const TextStyle(color: LF.muted)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    r.hasSynced
                        ? const Pill('Synchronisé', icon: Icons.bolt_rounded)
                        : const Pill('Texte seul',
                            color: LF.gold, icon: Icons.notes_rounded),
                    Pill(languageOf(song.language).name, color: LF.magenta),
                    if (r.duration != null)
                      Pill(formatDuration(r.duration!), color: LF.muted),
                  ]),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: LF.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.all(14),
                  itemCount: song.lines.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(
                      song.lines[i].isBreak ? '♪' : song.lines[i].text,
                      style: TextStyle(
                          color: song.lines[i].isBreak ? LF.muted : LF.text),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                label: store.contains(song.id)
                    ? 'Ouvrir dans le lecteur'
                    : 'Ajouter et ouvrir',
                icon: Icons.play_arrow_rounded,
                onPressed: () {
                  Navigator.pop(ctx);
                  openSong(context, store.byId(song.id) ?? song);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _importFile() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = res?.files.single.path;
    if (path == null || !mounted) return;
    try {
      final bytes = await File(path).readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
      final name = res!.files.single.name.replaceAll(RegExp(r'\.(lrc|txt)$', caseSensitive: false), '');
      if (!mounted) return;
      _showManualEditor(initialText: text, initialTitle: name);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fichier illisible.')));
    }
  }

  void _showManualEditor({String initialText = '', String initialTitle = ''}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ManualEditor(
        initialText: initialText,
        initialTitle: initialTitle,
        onCreate: (song) {
          Navigator.pop(ctx);
          openSong(context, song);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Rechercher',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Titre, artiste…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _search,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _importFile,
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Importer .lrc'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showManualEditor(),
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: const Text('Coller des paroles'),
                ),
              ),
            ]),
          ]),
        ),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: WaveBars(height: 46, bars: 9));
    }
    if (_error != null) {
      return _Empty(icon: Icons.wifi_off_rounded, text: _error!);
    }
    if (!_searched) {
      return const _Empty(
        icon: Icons.lyrics_rounded,
        text:
            'Cherche une chanson pour obtenir ses paroles synchronisées.\nSource : LRCLIB, base de paroles libre et gratuite.',
      );
    }
    if (_results.isEmpty) {
      return const _Empty(
        icon: Icons.search_off_rounded,
        text:
            'Aucune parole trouvée.\nEssaie « artiste titre », ou colle les paroles toi-même.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final r = _results[i];
        return Card(
          child: ListTile(
            onTap: () => _preview(r),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Icon(
              r.hasSynced ? Icons.graphic_eq_rounded : Icons.notes_rounded,
              color: r.hasSynced ? LF.cyan : LF.gold,
            ),
            title: Text(r.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              [r.artist, if (r.album.isNotEmpty) r.album].join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: LF.muted),
            ),
            trailing: r.duration != null
                ? Text(formatDuration(r.duration!),
                    style: const TextStyle(color: LF.muted))
                : null,
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 56, color: LF.violet),
          const SizedBox(height: 14),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: LF.muted, height: 1.4)),
        ]),
      ),
    );
  }
}

/// Saisie manuelle de paroles (LRC ou texte brut).
class _ManualEditor extends StatefulWidget {
  final String initialText;
  final String initialTitle;
  final void Function(Song song) onCreate;
  const _ManualEditor(
      {required this.initialText,
      required this.initialTitle,
      required this.onCreate});

  @override
  State<_ManualEditor> createState() => _ManualEditorState();
}

class _ManualEditorState extends State<_ManualEditor> {
  late final _title = TextEditingController(text: widget.initialTitle);
  final _artist = TextEditingController();
  late final _text = TextEditingController(text: widget.initialText);

  @override
  void initState() {
    super.initState();
    final p = LrcParser.parse(widget.initialText);
    if (p.title != null && p.title!.isNotEmpty) _title.text = p.title!;
    if (p.artist != null) _artist.text = p.artist!;
  }

  @override
  void dispose() {
    _title.dispose();
    _artist.dispose();
    _text.dispose();
    super.dispose();
  }

  void _create() {
    final parsed = LrcParser.parse(_text.text);
    if (parsed.lines.where((l) => !l.isBreak).isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajoute au moins une ligne de paroles.')));
      return;
    }
    final sample = parsed.lines.take(30).map((l) => l.text).join(' ');
    widget.onCreate(Song(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      title: _title.text.trim().isEmpty ? 'Sans titre' : _title.text.trim(),
      artist: _artist.text.trim().isEmpty ? 'Artiste inconnu' : _artist.text.trim(),
      lines: parsed.lines,
      language: LanguageGuesser.guess(sample),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Nouvelle chanson',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Colle des paroles brutes ou au format LRC ([00:12.00] ligne…). '
            'Tu pourras les synchroniser ensuite dans le lecteur.',
            style: TextStyle(color: LF.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
              controller: _title,
              decoration: const InputDecoration(hintText: 'Titre')),
          const SizedBox(height: 10),
          TextField(
              controller: _artist,
              decoration: const InputDecoration(hintText: 'Artiste')),
          const SizedBox(height: 10),
          TextField(
            controller: _text,
            minLines: 8,
            maxLines: 14,
            decoration: const InputDecoration(hintText: 'Paroles…'),
          ),
          const SizedBox(height: 16),
          GradientButton(
              label: 'Créer et ouvrir',
              icon: Icons.check_rounded,
              onPressed: _create),
        ]),
      ),
    );
  }
}
