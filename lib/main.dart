import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_shell.dart';
import 'services/library_store.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: LF.surface,
  ));
  final store = LibraryStore()..load();
  runApp(LyricFlowApp(store: store));
}

class LyricFlowApp extends StatelessWidget {
  final LibraryStore store;
  const LyricFlowApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return LibraryScope(
      store: store,
      child: MaterialApp(
        title: 'LyricFlow',
        debugShowCheckedModeBanner: false,
        theme: LF.theme(),
        home: const HomeShell(),
      ),
    );
  }
}
