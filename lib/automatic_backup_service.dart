import 'dart:io';

import 'package:path_provider/path_provider.dart';

class FoodBackupEntry {
  const FoodBackupEntry({
    required this.id,
    required this.fileName,
    required this.savedAt,
    required this.path,
  });

  final String id;
  final String fileName;
  final DateTime savedAt;
  final String path;
}

class FoodBackupService {
  const FoodBackupService({
    Future<Directory> Function()? directoryProvider,
    this.retentionCount = 20,
    this.minimumBackupInterval = const Duration(minutes: 15),
  }) : _directoryProvider = directoryProvider;

  final Future<Directory> Function()? _directoryProvider;
  final int retentionCount;
  final Duration minimumBackupInterval;

  Future<void> saveAutomaticBackup(
    String exportJson, {
    bool force = false,
  }) async {
    final Directory directory = await _backupDirectory();
    await directory.create(recursive: true);

    final List<File> files = directory.listSync().whereType<File>().toList(
      growable: true,
    );
    files.sort(_compareFilesNewestFirst);

    if (files.isNotEmpty) {
      final File latestFile = files.first;
      final String latestContents = await latestFile.readAsString();
      if (latestContents == exportJson) {
        return;
      }

      if (!force) {
        final DateTime latestSavedAt = await latestFile.lastModified();
        if (DateTime.now().difference(latestSavedAt) < minimumBackupInterval) {
          await latestFile.writeAsString(exportJson, flush: true);
          await _pruneExcessBackups(files);
          return;
        }
      }
    }

    final File backupFile = File('${directory.path}/${_timestampedFileName()}');
    await backupFile.writeAsString(exportJson, flush: true);
    await _pruneExcessBackups(<File>[backupFile, ...files]);
  }

  Future<List<FoodBackupEntry>> listBackups() async {
    final Directory directory = await _backupDirectory();
    if (!await directory.exists()) {
      return const <FoodBackupEntry>[];
    }

    final List<File> files = directory.listSync().whereType<File>().toList(
      growable: true,
    );
    files.sort(_compareFilesNewestFirst);

    final List<FoodBackupEntry> backups = <FoodBackupEntry>[];
    for (final File file in files) {
      final DateTime savedAt = await file.lastModified();
      backups.add(
        FoodBackupEntry(
          id: file.uri.pathSegments.last,
          fileName: file.uri.pathSegments.last,
          savedAt: savedAt,
          path: file.path,
        ),
      );
    }
    return backups;
  }

  Future<String> readBackup(String backupId) async {
    final String sanitizedId = backupId.trim();
    if (sanitizedId.isEmpty ||
        sanitizedId.contains('/') ||
        sanitizedId.contains('\\')) {
      throw const FormatException('Invalid backup identifier.');
    }

    final Directory directory = await _backupDirectory();
    final File backupFile = File('${directory.path}/$sanitizedId');
    if (!await backupFile.exists()) {
      throw StateError('Backup "$sanitizedId" could not be found.');
    }
    return backupFile.readAsString();
  }

  Future<Directory> _backupDirectory() async {
    final Future<Directory> Function()? directoryProvider = _directoryProvider;
    if (directoryProvider != null) {
      return directoryProvider();
    }

    final Directory supportDirectory = await getApplicationSupportDirectory();
    return Directory('${supportDirectory.path}/automatic_backups');
  }

  Future<void> _pruneExcessBackups(List<File> files) async {
    if (retentionCount < 1) {
      for (final File file in files) {
        if (await file.exists()) {
          await file.delete();
        }
      }
      return;
    }

    files.sort(_compareFilesNewestFirst);
    for (int index = retentionCount; index < files.length; index += 1) {
      final File file = files[index];
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  int _compareFilesNewestFirst(File a, File b) {
    final DateTime aModified = a.statSync().modified;
    final DateTime bModified = b.statSync().modified;
    return bModified.compareTo(aModified);
  }

  String _timestampedFileName() {
    final String sanitizedTimestamp = DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-');
    return 'family-eating-auto-backup-$sanitizedTimestamp.json';
  }
}
