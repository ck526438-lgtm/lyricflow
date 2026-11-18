import '../models/song.dart';
import '../services/lrc_parser.dart';

/// Chansons de démonstration ORIGINALES (paroles écrites pour LyricFlow,
/// libres de droits) pour tester l'appli sans connexion ni fichier audio.
const _learnTheFlow = '''
[ti:Learn the Flow]
[ar:LyricFlow Studio]
[00:02.00]Turn the volume up and let the rhythm in
[00:06.00]Every single word is where the dreams begin
[00:10.00]Read it on the screen, then sing it from your heart
[00:14.00]One line at a time, that's how the legends start
[00:18.00]
[00:19.00]Learn the flow, feel the beat
[00:22.50]Every verse becomes your own
[00:26.00]Learn the flow, don't retreat
[00:29.50]Sing it loud until it's known
[00:33.00]
[00:34.00]If the chorus slips away, just play it back again
[00:38.00]Loop the hardest part until it's second nature, friend
[00:42.00]Translate every phrase, discover what it means
[00:46.00]Music is a teacher hiding in the in-betweens
[00:50.00]
[00:51.00]Learn the flow, feel the beat
[00:54.50]Every verse becomes your own
[00:58.00]Learn the flow, don't retreat
[01:01.50]Sing it loud until it's known
[01:06.00]Learn the flow
''';

const _leRythme = '''
[ti:Le Rythme des Mots]
[ar:LyricFlow Studio]
[00:02.00]Sous les lumières d'Abidjan la nuit
[00:06.00]Je cherche les mots qui font danser ma vie
[00:10.00]Chaque refrain que j'apprends par cœur
[00:14.00]Devient une étoile, un peu de bonheur
[00:18.00]
[00:19.00]Chante avec moi, mot après mot
[00:23.00]Le rythme nous porte toujours plus haut
[00:27.00]Chante avec moi, ne lâche rien
[00:31.00]Les paroles deviennent ton chemin
''';

List<Song> buildDemoSongs() {
  Song make(String id, String lrc, String lang) {
    final p = LrcParser.parseLrc(lrc);
    return Song(
      id: id,
      title: p.title ?? 'Démo',
      artist: p.artist ?? 'LyricFlow',
      album: 'Démo LyricFlow',
      lines: p.lines,
      language: lang,
    );
  }

  return [
    make('demo-learn-the-flow', _learnTheFlow, 'en'),
    make('demo-le-rythme', _leRythme, 'fr'),
  ];
}
