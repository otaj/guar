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

  final String? Function(String absolutePath) readFile;

  final Map<String, String> _contexts = {};
  final List<String> includeLog = [];

  factory IncludeController.io() {
    return IncludeController(
      readFile: (path) {
        final file = File(path);
        if (!file.existsSync()) {
          return null;
        }
        return file.readAsStringSync();
      },
    );
  }

  IncludeOutcome open({required String pattern, required String fromFilename, required String contextKey}) {
    final matches = _expand(pattern, fromFilename);
    if (matches.isEmpty) {
      return IncludeFailed();
    }
    final loaded = <IncludeHit>[];
    for (final path in matches) {
      final absolute = File(path).absolute.path;
      final prior = _contexts[absolute];
      if (prior != null) {
        if (prior == contextKey) {
          continue;
        }
        return IncludeDuplicate();
      }
      final source = readFile(absolute);
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
    final baseDir = fromFilename.isEmpty ? Directory.current.path : File(fromFilename).parent.path;
    final sep = Platform.pathSeparator;
    final combined = pattern.startsWith('/') ? pattern : '$baseDir$sep$pattern';
    if (!_isGlob(pattern)) {
      return [combined];
    }
    final slash = combined.lastIndexOf(sep);
    final dirPath = slash < 0 ? baseDir : combined.substring(0, slash);
    final nameGlob = slash < 0 ? combined : combined.substring(slash + 1);
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      return [];
    }
    final out = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.isEmpty ? entity.path : entity.uri.pathSegments.last;
      if (_globMatch(name, nameGlob)) {
        out.add(entity.path);
      }
    }
    out.sort();
    return out;
  }

  bool _isGlob(String pattern) => pattern.contains('*') || pattern.contains('?') || pattern.contains('[');

  bool _globMatch(String name, String glob) {
    final buf = StringBuffer('^');
    for (var i = 0; i < glob.length; i++) {
      final ch = glob[i];
      if (ch == '*') {
        buf.write('.*');
      } else if (ch == '?') {
        buf.write('.');
      } else if (ch == '[') {
        final end = glob.indexOf(']', i + 1);
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
