import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/library_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'practice_screen.dart';

enum _Filter { all, favorites, learning, mastered }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _Filter _filter = _Filter.all;

  bool _keep(Song s) {
    switch (_filter) {
      case _Filter.all:
        return true;
      case _Filter.favorites:
        return s.favorite;
      case _Filter.learning:
        return s.progress < 0.8;
      case _Filter.mastered:
        return s.progress >= 0.8;
    }
  }

  Future<bool> _confirmDelete(Song s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: LF.surface,
        title: const Text('Retirer la chanson ?'),
        content: Text(
            '« ${s.title} » et ta progression seront supprimés de cet appareil.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Retirer', style: TextStyle(color: LF.danger))),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final store = LibraryScope.of(context);
    final songs = store.songs.where(_keep).toList();
    final labels = {
      _Filter.all: 'Toutes',
      _Filter.favorites: 'Favoris',
      _Filter.learning: 'En cours',
      _Filter.mastered: 'Maîtrisées',
    };

    return SafeArea(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Row(children: [
            const Expanded(
              child: Text('Ma bibliothèque',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            ),
            Pill('${store.totalSessions} séances',
                color: LF.gold, icon: Icons.school_rounded),
          ]),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            children: [
              for (final f in _Filter.values)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(labels[f]!),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: LF.violet.withValues(alpha: 0.35),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: !store.loaded
              ? const Center(child: CircularProgressIndicator())
              : songs.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const WaveBars(height: 40, bars: 7, animate: false),
                          const SizedBox(height: 16),
                          Text(
                            _filter == _Filter.all
                                ? 'Ta bibliothèque est vide.\nRecherche une chanson ou ouvre une démo depuis l\'accueil.'
                                : 'Aucune chanson dans cette catégorie.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: LF.muted, height: 1.4),
                          ),
                        ]),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      itemCount: songs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = songs[i];
                        return Dismissible(
                          key: ValueKey(s.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => _confirmDelete(s),
                          onDismissed: (_) => store.remove(s.id),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: LF.danger.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.delete_outline_rounded,
                                color: LF.danger),
                          ),
                          child: SongTile(
                            song: s,
                            onTap: () => openSong(context, s),
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                tooltip: 'Favori',
                                icon: Icon(
                                  s.favorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  color: s.favorite ? LF.magenta : LF.muted,
                                ),
                                onPressed: () {
                                  s.favorite = !s.favorite;
                                  store.update(s);
                                },
                              ),
                              IconButton(
                                tooltip: 'S\'entraîner',
                                icon: const Icon(Icons.school_rounded,
                                    color: LF.cyan),
                                onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            PracticeScreen(songId: s.id))),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}
