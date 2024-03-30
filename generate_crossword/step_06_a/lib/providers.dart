// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:built_collection/built_collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'model.dart' as model;
import 'utils.dart';

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

final _random = Random();

@riverpod
Stream<model.Crossword> crossword(CrosswordRef ref) async* {
  final size = ref.watch(sizeProvider);
  final wordListAsync = ref.watch(wordListProvider);

  var crossword =
      model.Crossword.crossword(width: size.width, height: size.height);

  yield* wordListAsync.when(
    data: (wordList) async* {
      while (crossword.characters.length < size.width * size.height * 0.8) {
        final word = wordList.randomElement();
        final direction =
            _random.nextBool() ? model.Direction.across : model.Direction.down;
        final location = model.Location.at(
            _random.nextInt(size.width), _random.nextInt(size.height));

        var candidate = crossword.addWord(
            word: word, direction: direction, location: location);
        await Future.delayed(Duration(milliseconds: 10));
        if (candidate != null) {
          debugPrint('Added word: $word');
          crossword = candidate;
          yield crossword;
        } else {
          debugPrint('Failed to add word: $word');
        }
      }

      yield crossword;
    },
    error: (error, stackTrace) async* {
      debugPrint('Error loading word list: $error');
      yield crossword;
    },
    loading: () async* {
      yield crossword;
    },
  );
}
