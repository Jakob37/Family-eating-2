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

class UnsupportedDataFileAccess implements DataFileAccess {
  @override
  bool get supportsFilePickerFlow => false;

  @override
  Future<String?> pickDirectoryPath({String? dialogTitle}) async => null;

  @override
  Future<PickedTextFile?> pickTextFile({
    List<String> allowedExtensions = const <String>['json'],
    String? dialogTitle,
  }) async => null;

  @override
  Future<String?> writeTextFile({
    required String directoryPath,
    required String filename,
    required String contents,
  }) async => null;
}

DataFileAccess createDataFileAccess() => UnsupportedDataFileAccess();
