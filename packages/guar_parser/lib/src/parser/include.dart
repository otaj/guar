// Resolves Beancount include paths, globs, and duplicate-include context.

import 'dart:io';

class IncludeHit {
  IncludeHit({required this.path, required this.source});

  final String path;
  final String source;
}

sealed class IncludeOutcome {}

final class IncludeSkip extends IncludeOutcome {}

final class IncludeDuplicate extends IncludeOutcome {}

final class IncludeFailed extends IncludeOutcome {}

final class IncludeLoaded extends IncludeOutcome {
  IncludeLoaded(this.files);
  final List<IncludeHit> files;
}

class IncludeController {
  IncludeController({required this.readFile});

  factory IncludeController.io() => IncludeController(
    readFile: (String path) {
      final File file = File(path);
      if (!file.existsSync()) {
        return null;
      }
      return file.readAsStringSync();
    },
  );

  final String? Function(String absolutePath) readFile;

  final Map<String, String> _contexts = <String, String>{};
  final List<String> includeLog = <String>[];

  IncludeOutcome open({required String pattern, required String fromFilename, required String contextKey}) {
    final List<String> matches = _expand(pattern, fromFilename);
    if (matches.isEmpty) {
      return IncludeFailed();
    }
    final List<IncludeHit> loaded = <IncludeHit>[];
    for (final String path in matches) {
      final String absolute = File(path).absolute.path;
      final String? prior = _contexts[absolute];
      if (prior != null) {
        if (prior == contextKey) {
          continue;
        }
        return IncludeDuplicate();
      }
      final String? source = readFile(absolute);
      if (source == null) {
        return IncludeFailed();
      }
      _contexts[absolute] = contextKey;
      includeLog.add(absolute);
      loaded.add(IncludeHit(path: absolute, source: source));
    }
    if (loaded.isEmpty) {
      return IncludeSkip();
    }
    return IncludeLoaded(loaded);
  }

  List<String> _expand(String pattern, String fromFilename) {
    final String baseDir = fromFilename.isEmpty ? Directory.current.path : File(fromFilename).parent.path;
    final String sep = Platform.pathSeparator;
    final String combined = pattern.startsWith('/') ? pattern : '$baseDir$sep$pattern';
    if (!_isGlob(pattern)) {
      return <String>[combined];
    }
    final int slash = combined.lastIndexOf(sep);
    final String dirPath = slash < 0 ? baseDir : combined.substring(0, slash);
    final String nameGlob = slash < 0 ? combined : combined.substring(slash + 1);
    final Directory dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return <String>[];
    }
    final List<String> out = <String>[];
    for (final FileSystemEntity entity in dir.listSync()) {
      if (entity is! File) {
        continue;
      }
      final String name = entity.uri.pathSegments.isEmpty ? entity.path : entity.uri.pathSegments.last;
      if (_globMatch(name, nameGlob)) {
        out.add(entity.path);
      }
    }
    out.sort();
    return out;
  }

  bool _isGlob(String pattern) => pattern.contains('*') || pattern.contains('?') || pattern.contains('[');

  bool _globMatch(String name, String glob) {
    final StringBuffer buf = StringBuffer('^');
    for (int i = 0; i < glob.length; i++) {
      final String ch = glob[i];
      if (ch == '*') {
        buf.write('.*');
      } else if (ch == '?') {
        buf.write('.');
      } else if (ch == '[') {
        final int end = glob.indexOf(']', i + 1);
        if (end < 0) {
          buf.write(r'\[');
        } else {
          buf.write(glob.substring(i, end + 1));
          i = end;
        }
      } else if (r'\.^$+{}()|'.contains(ch)) {
        buf.write('\\$ch');
      } else {
        buf.write(ch);
      }
    }
    buf.write(r'$');
    return RegExp(buf.toString()).hasMatch(name);
  }
}
