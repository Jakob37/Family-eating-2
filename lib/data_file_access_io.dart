import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

class PickedTextFile {
  const PickedTextFile({required this.name, required this.contents});

  final String name;
  final String contents;
}

abstract class DataFileAccess {
  bool get supportsFilePickerFlow;

  Future<String?> pickDirectoryPath({String? dialogTitle});

  Future<String?> writeTextFile({
    required String directoryPath,
    required String filename,
    required String contents,
  });

  Future<PickedTextFile?> pickTextFile({
    List<String> allowedExtensions = const <String>['json'],
    String? dialogTitle,
  });
}

class FilePickerDataFileAccess implements DataFileAccess {
  @override
  bool get supportsFilePickerFlow => true;

  @override
  Future<String?> pickDirectoryPath({String? dialogTitle}) {
    return FilePicker.platform.getDirectoryPath(dialogTitle: dialogTitle);
  }

  @override
  Future<PickedTextFile?> pickTextFile({
    List<String> allowedExtensions = const <String>['json'],
    String? dialogTitle,
  }) async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final PlatformFile file = result.files.single;
    if (file.bytes != null) {
      return PickedTextFile(
        name: file.name,
        contents: utf8.decode(file.bytes!),
      );
    }
    if (file.path == null) {
      return null;
    }
    return PickedTextFile(
      name: file.name,
      contents: await File(file.path!).readAsString(),
    );
  }

  @override
  Future<String?> writeTextFile({
    required String directoryPath,
    required String filename,
    required String contents,
  }) async {
    final String separator = Platform.pathSeparator;
    final String normalizedDirectory = directoryPath.endsWith(separator)
        ? directoryPath.substring(0, directoryPath.length - 1)
        : directoryPath;
    final String path = '$normalizedDirectory$separator$filename';
    final File file = File(path);
    await file.writeAsString(contents);
    return file.path;
  }
}

DataFileAccess createDataFileAccess() => FilePickerDataFileAccess();
