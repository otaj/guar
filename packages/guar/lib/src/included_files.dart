// Writes the included beancount files the parser loaded from disk.

import 'dart:io';

abstract interface class IncludedFiles {
  String? read(String path);

  void write(String path, String text);
}

class IoIncludedFiles implements IncludedFiles {
  const IoIncludedFiles();

  @override
  String? read(String path) {
    try {
      final File file = File(path);
      if (!file.existsSync()) return null;
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  @override
  void write(String path, String text) {
    File(path)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(text);
  }
}
