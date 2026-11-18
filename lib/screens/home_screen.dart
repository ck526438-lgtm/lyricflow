import 'package:flutter/material.dart';

import '../data/demo_songs.dart';
import '../services/library_store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'practice_screen.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onLibrary;
  const HomeScreen({super.key, required this.onSearch, required this.onLibrary});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bonjour';
    if (h < 18) return 'Bon après-midi';
    return 'Bonsoir';
  }

  @override
  Widget build(BuildContext context) {
    final store = LibraryScope.of(context);
    final last = store.lastOpened;
    final demos = buildDemoSongs();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset('assets/logo.png', width: 44, height: 44),
            ),
            const SizedBox(width: 12),
            const GradientText('LyricFlow',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const Spacer(),
            const WaveBars(bars: 5, height: 26, barWidth: 4),
          ]),
          const SizedBox(height: 22),
          Text('${_greeting()} 👋',
              style: const TextStyle(fontSize: 15, color: LF.muted)),
          const SizedBox(height: 4),
          const Text('Apprends les paroles\nde tes chansons préférées',
              style: TextStyle(
                  fontSize: 25, fontWeight: FontWeight.w800, height: 1.2)),
          const SizedBox(height: 18),

          // Barre de recherche factice -> onglet Recherche
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onSearch,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              decoration: BoxDecoration(
                color: LF.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: LF.border),
              ),
              child: const Row(children: [
                Icon(Icons.search_rounded, color: LF.muted),
                SizedBox(width: 10),
                Text('Titre, artiste…', style: TextStyle(color: LF.muted)),
              ]),
            ),
          ),
          const SizedBox(height: 20),

          _StatsRow(
            songs: store.songs.length,
            mastered: store.totalMasteredLines,
            streak: store.streak,
          ),
          const SizedBox(height: 24),

          if (last != null) ...[
            const _SectionTitle('Continuer'),
            const SizedBox(height: 10),
            _ContinueCard(songId: last.id),
            const SizedBox(height: 24),
          ],

          const _SectionTitle('Chansons de démo'),
          const SizedBox(height: 4),
          const Text(
            'Paroles originales, pour tout essayer sans connexion.',
            style: TextStyle(color: LF.muted, fontSize: 13),
          ),
          const SizedBox(height: 10),
          for (final d in demos) ...[
            SongTile(
              song: store.byId(d.id) ?? d,
              onTap: () => openSong(context, store.byId(d.id) ?? d),
              trailing: const Icon(Icons.play_circle_fill_rounded,
                  color: LF.cyan, size: 36),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          const _SectionTitle('Comment ça marche'),
          const SizedBox(height: 10),
          const _HowItWorks(),
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: onLibrary,
              icon: const Icon(Icons.library_music_rounded),
              label: const Text('Voir ma bibliothèque'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));
}

class _StatsRow extends StatelessWidget {
  final int songs, mastered, streak;
  const _StatsRow(
      {required this.songs, required this.mastered, required this.streak});

  @override
  Widget build(BuildContext context) {
    Widget stat(IconData icon, String value, String label, Color color) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: LF.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: LF.border),
            ),
            child: Column(children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(value,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11.5, color: LF.muted)),
            ]),
          ),
        );
    return Row(children: [
      stat(Icons.library_music_rounded, '$songs', 'chansons', LF.magenta),
      const SizedBox(width: 10),
      stat(Icons.school_rounded, '$mastered', 'lignes maîtrisées', LF.gold),
      const SizedBox(width: 10),
      stat(Icons.local_fire_department_rounded, '$streak',
          streak > 1 ? 'jours de suite' : 'jour de suite', LF.cyan),
    ]);
  }
}

class _ContinueCard extends StatelessWidget {
  final String songId;
  const _ContinueCard({required this.songId});

  @override
  Widget build(BuildContext context) {
    final store = LibraryScope.of(context);
    final song = store.byId(songId);
    if (song == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        gradient: LF.softGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: LF.violet.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SongArt(song: song, size: 58),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              Text(song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: LF.muted)),
              const SizedBox(height: 6),
              Text('${song.masteredLines}/${song.textIndexes.length} lignes maîtrisées',
                  style: const TextStyle(fontSize: 12.5, color: LF.cyan)),
            ]),
          ),
          ProgressRing(value: song.progress, size: 54),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: GradientButton(
              label: 'Écouter',
              icon: Icons.play_arrow_rounded,
              compact: true,
              onPressed: () => openSong(context, song),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: LF.cyan),
                foregroundColor: LF.cyan,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => PracticeScreen(songId: song.id))),
              icon: const Icon(Icons.school_rounded),
              label: const Text('S\'entraîner'),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.search_rounded, LF.magenta, 'Trouve une chanson',
          'Paroles synchronisées depuis LRCLIB, ou importe ton fichier .lrc.'),
      (Icons.graphic_eq_rounded, LF.violet, 'Suis le rythme',
          'Ajoute ton fichier audio : les paroles défilent en temps réel.'),
      (Icons.repeat_rounded, LF.blue, 'Répète les passages durs',
          'Boucle une ligne ou un refrain, ralentis la vitesse.'),
      (Icons.translate_rounded, LF.cyan, 'Comprends le sens',
          'Traduction ligne par ligne et notes personnelles.'),
      (Icons.school_rounded, LF.gold, 'Mémorise',
          'Flashcards, texte à trous, mémoire progressive, ordre des lignes.'),
    ];
    return Column(
      children: [
        for (final it in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: it.$2.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(it.$1, color: it.$2, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.$3, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(it.$4,
                      style: const TextStyle(color: LF.muted, fontSize: 13)),
                ]),
              ),
            ]),
          ),
      ],
    );
  }
}
