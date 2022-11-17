import 'dart:convert';
import 'dart:io';

import 'package:cli_script/cli_script.dart';
import 'package:io/io.dart' as io;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

import 'blueprint.dart';

final _logger = Logger('rebuild_blueprint');

Future<void> rebuildFromBlueprint(Directory cwd, Blueprint blueprint) async {
  _logger.info(blueprint.name);

  if (!blueprint.isValid) {
    _logger.warning('Invalid blueprint');
    exit(-1);
  }

  for (final step in blueprint.steps) {
    await _buildBlueprintStep(cwd, step);
  }
}

Future<void> _buildBlueprintStep(Directory cwd, BlueprintStep step) async {
  _logger.info(step.name);

  final stop = step.stop;
  if (stop != null && stop == true) {
    _logger.info('Stopping.');
    exit(0);
  }

  final platforms = step.platforms;
  if (platforms != null) {
    if (!platforms.contains(Platform.operatingSystem)) {
      _logger.info(
          'Skipping because ${Platform.operatingSystem} is not in ${platforms.join(', ')}.');
      return;
    }
  }

  final steps = step.steps;
  if (steps.isNotEmpty) {
    for (final subStep in steps) {
      await _buildBlueprintStep(cwd, subStep);
    }
    return;
  }

  if (step.mkdir != null || step.mkdirs.isNotEmpty) {
    final dir = step.mkdir;
    if (dir != null) {
      _mkdir(
          step.path != null
              ? p.join(cwd.path, step.path, dir)
              : p.join(cwd.path, dir),
          step: step);
    } else {
      for (final dir in step.mkdirs) {
        _mkdir(
            step.path != null
                ? p.join(cwd.path, step.path, dir)
                : p.join(cwd.path, dir),
            step: step);
      }
    }
    return;
  }

  if (step.rmdir != null || step.rmdirs.isNotEmpty) {
    final dir = step.rmdir;
    if (dir != null) {
      _rmdir(
          step.path != null
              ? p.join(cwd.path, step.path, dir)
              : p.join(cwd.path, dir),
          step: step);
    } else {
      for (final dir in step.rmdirs) {
        _rmdir(
            step.path != null
                ? p.join(cwd.path, step.path, dir)
                : p.join(cwd.path, dir),
            step: step);
      }
    }
    return;
  }

  final rename = step.rename;
  if (rename != null) {
    if (step.path != null) {
      _rename(
          from: p.join(cwd.path, step.path, rename.from),
          to: p.join(cwd.path, step.path, rename.to),
          step: step);
    } else {
      _rename(
          from: p.join(cwd.path, rename.from),
          to: p.join(cwd.path, rename.to),
          step: step);
    }
    return;
  }

  final cpdir = step.copydir;
  if (cpdir != null) {
    if (step.path != null) {
      _cpdir(
          from: p.join(cwd.path, step.path, cpdir.from),
          to: p.join(cwd.path, step.path, cpdir.to),
          step: step);
    } else {
      _cpdir(
          from: p.join(cwd.path, cpdir.from),
          to: p.join(cwd.path, cpdir.to),
          step: step);
    }
    return;
  }

  final rm = step.rm;
  if (rm != null) {
    late final File target;
    if (step.path != null) {
      target = File(p.join(cwd.path, step.path, rm));
    } else {
      target = File(p.join(cwd.path, rm));
    }
    if (!target.existsSync()) {
      _logger.severe("File ${target.path} doesn't exist: ${step.name}");
      exit(-1);
    }
    target.deleteSync();
    return;
  }

  final pod = step.pod;
  if (pod != null) {
    await _runNamedCommand(
      command: 'pod',
      step: step,
      cwd: cwd,
      args: pod,
    );
    return;
  }

  final dart = step.dart;
  if (dart != null) {
    await _runNamedCommand(
      command: 'dart',
      step: step,
      cwd: cwd,
      args: dart,
    );
    return;
  }

  final flutter = step.flutter;
  if (flutter != null) {
    await _runNamedCommand(
      command: 'flutter',
      step: step,
      cwd: cwd,
      args: flutter,
    );
    return;
  }

  final git = step.git;
  if (git != null) {
    await _runNamedCommand(
      command: 'git',
      step: step,
      cwd: cwd,
      args: git,
    );
    return;
  }

  final path = step.path;
  if (path == null) {
    _logger.severe(
        'patch, base64-contents and replace-contents require a path: ${step.name}');
    exit(-1);
  }

  final patch = step.patch;
  final patchU = step.patchU;
  final patchC = step.patchC;

  if (patch != null || patchC != null || patchU != null) {
    final fullPath = p.join(cwd.path, path);
    if (!FileSystemEntity.isFileSync(fullPath)) {
      File(fullPath).createSync();
    }

    late final Script script;
    if (patch != null) {
      script =
          patch | Script('patch', args: [path], workingDirectory: cwd.path);
    }
    if (patchC != null) {
      script = patchC |
          Script('patch', args: ['-c', path], workingDirectory: cwd.path);
    }
    if (patchU != null) {
      script = patchU |
          Script('patch', args: ['-u', path], workingDirectory: cwd.path);
    }
    script.stderr.lines.listen((event) {
      _logger.warning(event);
    });
    script.stdout.lines.listen((event) {
      _logger.info(event);
    });

    final exitCode = await script.exitCode;
    if (exitCode != 0) {
      _logger.severe('Patch failed');
      exit(-1);
    }

    return;
  }

  final base64Contents = step.base64Contents;
  if (base64Contents != null) {
    File(p.join(cwd.path, path))
        .writeAsBytesSync(base64Decode(base64Contents.split('\n').join('')));
    return;
  }

  final replaceContents = step.replaceContents;
  if (replaceContents != null) {
    File(p.join(cwd.path, path)).writeAsStringSync(replaceContents);
    return;
  }

  // Shouldn't get this far.
  _logger.severe('Invalid step: ${step.name}');
  exit(-1);
}

Future<void> _runNamedCommand({
  required String command,
  required BlueprintStep step,
  required Directory cwd,
  required String args,
}) async {
  final String workingDirectory =
      step.path != null ? p.join(cwd.path, step.path) : cwd.path;
  final script = Script(
    command,
    args: io.shellSplit(args),
    workingDirectory: workingDirectory,
  );
  script.stderr.lines.listen((event) {
    _logger.warning(event);
  });
  script.stdout.lines.listen((event) {
    _logger.info(event);
  });

  final exitCode = await script.exitCode;
  if (exitCode != 0) {
    _logger.severe('Patch failed');
    exit(-1);
  }
  return;
}

void _rename({
  required String from,
  required String to,
  required BlueprintStep step,
}) {
  File(from).renameSync(to);
}

void _cpdir({
  required String from,
  required String to,
  required BlueprintStep step,
}) {
  if (!FileSystemEntity.isDirectorySync(from)) {
    _logger.warning("Invalid cpdir for '$from': ${step.name}");
  }
  io.copyPathSync(from, to);
}

void _rmdir(String dir, {required BlueprintStep step}) {
  if (!FileSystemEntity.isDirectorySync(dir)) {
    _logger.warning("Invalid rmdir for '$dir': ${step.name}");
  }
  Directory(dir).deleteSync(recursive: true);
}

void _mkdir(String dir, {required BlueprintStep step}) {
  Directory(dir).createSync(recursive: true);
}
