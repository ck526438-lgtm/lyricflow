import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Sélectionne un fichier audio et le copie dans le dossier de l'appli,
/// pour qu'il reste disponible même si le cache est vidé.
Future<String?> pickAndStoreAudio(String songId) async {
  final res = await FilePicker.platform.pickFiles(type: FileType.audio);
  final picked = res?.files.single;
  final path = picked?.path;
  if (picked == null || path == null) return null;

  final dir = await getApplicationDocumentsDirectory();
  final audioDir = Directory('${dir.path}/audio');
  if (!audioDir.existsSync()) audioDir.createSync(recursive: true);

  final ext = picked.extension ?? 'mp3';
  final safeId = songId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  final dest = File('${audioDir.path}/$safeId.$ext');
  if (dest.existsSync()) dest.deleteSync();
  await File(path).copy(dest.path);
  return dest.path;
}
