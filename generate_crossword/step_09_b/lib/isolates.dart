// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import 'model.dart';
import 'utils.dart';

Stream<WorkQueue> exploreCrosswordSolutions({
  required Crossword crossword,
  required BuiltSet<String> wordList,
  required int maxWorkerCount,
}) async* {
  final start = DateTime.now();
  var workQueue = WorkQueue.from(
    crossword: crossword,
    candidateWords: wordList,
    startLocation: Location.at(0, 0),
  );
  while (!workQueue.isCompleted) {
    try {
      workQueue = await compute(_generate, (workQueue, maxWorkerCount));
      yield workQueue;
    } catch (e) {
      debugPrint('Error running isolate: $e');
    }
  }

  debugPrint('Generated ${workQueue.crossword.width} x '
      '${workQueue.crossword.height} crossword in '
      '${DateTime.now().difference(start).formatted} '
      'with $maxWorkerCount workers.');
}

Future<WorkQueue> _generate((WorkQueue, int) args) async {
  var workQueue = args.$1;
  final maxWorkerCount = args.$2;
  final futures = <Future<(Location, Direction, String?)>>[];
  var locations =
      workQueue.locationsToTry.keys.toBuiltList().rebuild((b) => b.shuffle());

  for (int id = 0;
      id < min(maxWorkerCount, workQueue.locationsToTry.length);
      id = id + 1) {
    final location = locations.first;
    locations = locations.rebuild((b) => b.remove(location));
    final direction = workQueue.locationsToTry[location]!;

    futures.add(compute(_generateWorker,
        (workQueue.crossword, workQueue.candidateWords, location, direction)));
  }

  try {
    final results = await Future.wait(futures);
    var crossword = workQueue.crossword;
    for (final (location, direction, word) in results) {
      if (word != null) {
        final candidate = crossword.addWord(
            location: location, word: word, direction: direction);
        if (candidate != null) {
          crossword = candidate;
        }
      } else {
        workQueue = workQueue.remove(location);
      }
    }

    workQueue = workQueue.updateFrom(crossword);
  } catch (e) {
    debugPrint('$e');
  }

  return workQueue;
}

(Location, Direction, String?) _generateWorker(
    (Crossword, BuiltSet<String>, Location, Direction) args) {
  final (crossword, candidateWords, location, direction) = args;

  final target = crossword.characters[location];
  if (target == null) {
    return (location, direction, candidateWords.randomElement());
  }

  // Filter down the candidate word list to those that contain the letter
  // at the current location
  var words = candidateWords.toBuiltList().rebuild((b) => b
    ..where((b) => b.characters.contains(target.character))
    ..shuffle());
  int tryCount = 0;
  final start = DateTime.now();
  for (final word in words) {
    tryCount++;
    for (final (index, character) in word.characters.indexed) {
      if (character != target.character) continue;

      final candidate = switch (direction) {
        Direction.across => crossword.addWord(
            direction: Direction.across,
            location: location.leftOffset(index),
            word: word),
        Direction.down => crossword.addWord(
            direction: Direction.down,
            location: location.upOffset(index),
            word: word)
      };
      if (candidate != null) {
        return switch (direction) {
          Direction.across => (location.leftOffset(index), direction, word),
          Direction.down => (location.upOffset(index), direction, word),
        };
      }
      final deltaTime = DateTime.now().difference(start);
      if (tryCount >= 1000 || deltaTime > Duration(seconds: 10)) {
        return (location, direction, null);
      }
    }
  }

  return (location, direction, null);
}