import 'package:flutter/material.dart';

import '../models/song.dart';
import '../services/library_store.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'player_screen.dart';
import 'search_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(onSearch: () => _go(1), onLibrary: () => _go(2)),
      const SearchScreen(),
      const LibraryScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Accueil'),
          NavigationDestination(
              icon: Icon(Icons.search_rounded), label: 'Rechercher'),
          NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music_rounded),
              label: 'Bibliothèque'),
        ],
      ),
    );
  }
}

/// Ouvre le lecteur d'une chanson (en l'ajoutant à la bibliothèque si besoin).
Future<void> openSong(BuildContext context, Song song) async {
  final store = LibraryScope.read(context);
  final s = await store.add(song);
  await store.markOpened(s);
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => PlayerScreen(songId: s.id)),
  );
}
