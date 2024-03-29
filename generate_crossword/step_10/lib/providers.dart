// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'isolates.dart';
import 'model.dart' as model;

part 'providers.g.dart';

/// A provider for the wordlist to use when generating the crossword.
@riverpod
Future<BuiltSet<String>> wordList(WordListRef ref) async {
  // This codebase requires that all words consist of lowercase characters
  // in the range 'a'-'z'. Words containing uppercase letters will be
  // lowercased, and words containing runes outside this range will
  // be removed.

  final re = RegExp('^[a-z]+\$');
  final str = await rootBundle.loadString('assets/words.txt');
  return str.split('\n').toBuiltSet().rebuild((b) => b
    ..map((str) => str.toLowerCase().trim())
    ..removeWhere((str) => str.length < 3)
    ..removeWhere((str) => re.stringMatch(str) == null));
}

/// An enumeration for different sizes of [Crossword]s.
enum CrosswordSize {
  small(width: 20, height: 11),
  medium(width: 40, height: 22),
  large(width: 80, height: 44),
  xlarge(width: 160, height: 88),
  xxlarge(width: 500, height: 500);

  const CrosswordSize({
    required this.width,
    required this.height,
  });

  final int width;
  final int height;
  String get label => '$width x $height';
}

/// A provider that holds the current size of the crossword to generate.
@Riverpod(keepAlive: true)
class Size extends _$Size {
  var _size = CrosswordSize.medium;

  @override
  CrosswordSize build() => _size;

  void setSize(CrosswordSize size) {
    _size = size;
    ref.invalidateSelf();
  }
}

@riverpod
Stream<model.WorkQueue> workQueue(WorkQueueRef ref) async* {
  final workers = ref.watch(workerCountProvider);
  final size = ref.watch(sizeProvider);
  final wordListAsync = ref.watch(wordListProvider);
  final emptyCrossword =
      model.Crossword.crossword(width: size.width, height: size.height);
  final emptyWorkQueue = model.WorkQueue.from(
    crossword: emptyCrossword,
    candidateWords: BuiltSet<String>(),
    startLocation: model.Location.at(0, 0),
  );

  ref.read(startTimeProvider.notifier).start();
  ref.read(endTimeProvider.notifier).clear();

  yield* wordListAsync.when(
    data: (wordList) => exploreCrosswordSolutions(
      crossword: emptyCrossword,
      wordList: wordList,
      maxWorkerCount: workers.count,
    ),
    error: (error, stackTrace) async* {
      debugPrint('Error loading word list: $error');
      yield emptyWorkQueue;
    },
    loading: () async* {
      yield emptyWorkQueue;
    },
  );

  ref.read(endTimeProvider.notifier).end();
}

@Riverpod(keepAlive: true)
class StartTime extends _$StartTime {
  @override
  DateTime? build() => _start;

  DateTime? _start;

  void start() {
    _start = DateTime.now();
    ref.invalidateSelf();
  }
}

@Riverpod(keepAlive: true)
class EndTime extends _$EndTime {
  @override
  DateTime? build() => _end;

  DateTime? _end;

  void clear() {
    _end = null;
    ref.invalidateSelf();
  }

  void end() {
    _end = DateTime.now();
    ref.invalidateSelf();
  }
}

const _estimatedTotalCoverage = 0.54;

@riverpod
Duration expectedRemainingTime(ExpectedRemainingTimeRef ref) {
  final startTime = ref.watch(startTimeProvider);
  final endTime = ref.watch(endTimeProvider);
  final workQueueAsync = ref.watch(workQueueProvider);

  return workQueueAsync.when(
    data: (workQueue) {
      if (startTime == null || endTime != null || workQueue.isCompleted) {
        return Duration.zero;
      }
      try {
        final soFar = DateTime.now().difference(startTime);
        final completedPercentage = min(
            0.99,
            (workQueue.crossword.characters.length /
                (workQueue.crossword.width * workQueue.crossword.height) /
                _estimatedTotalCoverage));
        final expectedTotal = soFar.inSeconds / completedPercentage;
        final expectedRemaining = expectedTotal - soFar.inSeconds;
        return Duration(seconds: expectedRemaining.toInt());
      } catch (e) {
        return Duration.zero;
      }
    },
    error: (error, stackTrace) => Duration.zero,
    loading: () => Duration.zero,
  );
}

/// A provider that holds whether to display info.
@Riverpod(keepAlive: true)
class ShowDisplayInfo extends _$ShowDisplayInfo {
  var _display = true;

  @override
  bool build() => _display;

  void toggle() {
    _display = !_display;
    ref.invalidateSelf();
  }
}

/// A provider that summarise the DisplayInfo from a [model.WorkQueue].
@riverpod
class DisplayInfo extends _$DisplayInfo {
  @override
  model.DisplayInfo build() => ref.watch(workQueueProvider).when(
        data: (workQueue) => model.DisplayInfo.from(workQueue: workQueue),
        error: (error, stackTrace) => model.DisplayInfo.empty,
        loading: () => model.DisplayInfo.empty,
      );
}

enum BackgroundWorkers {
  one(1),
  two(2),
  four(4),
  eight(8),
  sixteen(16),
  thirtyTwo(32),
  sixtyFour(64),
  oneTwentyEight(128);

  const BackgroundWorkers(this.count);

  final int count;
  String get label => count.toString();
}

/// A provider that holds the current number of background workers to use.
@Riverpod(keepAlive: true)
class WorkerCount extends _$WorkerCount {
  var _count = BackgroundWorkers.four;

  @override
  BackgroundWorkers build() => _count;

  void setCount(BackgroundWorkers count) {
    _count = count;
    ref.invalidateSelf();
  }
}

@riverpod
class Puzzle extends _$Puzzle {
  model.CrosswordPuzzleGame _puzzle = model.CrosswordPuzzleGame.from(
    crossword: model.Crossword.crossword(width: 0, height: 0),
    candidateWords: BuiltSet<String>(),
  );

  @override
  model.CrosswordPuzzleGame build() {
    final size = ref.watch(sizeProvider);
    final wordListAsync = ref.watch(wordListProvider);
    final workQueueAsync = ref.watch(workQueueProvider);

    if (wordListAsync.hasValue && workQueueAsync.hasValue) {
      // Reset the game if required.
      if (workQueueAsync.value!.isCompleted &&
          (_puzzle.crossword.height != size.height ||
              _puzzle.crossword.width != size.width ||
              _puzzle.crossword != workQueueAsync.value!.crossword)) {
        _puzzle = model.CrosswordPuzzleGame.from(
            crossword: workQueueAsync.value!.crossword,
            candidateWords: wordListAsync.value!);
      }
    }

    return _puzzle;
  }

  Future<void> selectWord({
    required model.Location location,
    required String word,
    required model.Direction direction,
  }) async {
    final candidate = await compute(_puzzleSelectWordIsolateTrampoline,
        (_puzzle, location, word, direction));

    if (candidate != null) {
      _puzzle = candidate;
      ref.invalidateSelf();
    } else {
      debugPrint('Invalid word selection: $word');
    }
  }

  bool canSelectWord({
    required model.Location location,
    required String word,
    required model.Direction direction,
  }) {
    return _puzzle.canSelectWord(
      location: location,
      word: word,
      direction: direction,
    );
  }
}

/// Trampoline function to disentangle this computation from the
/// unsendable reference to the [Puzzle] provider.
model.CrosswordPuzzleGame? _puzzleSelectWordIsolateTrampoline(
    (model.CrosswordPuzzleGame, model.Location, String, model.Direction) args) {
  final (puzzle, location, word, direction) = args;
  return puzzle.selectWord(
      location: location, word: word, direction: direction);
}
