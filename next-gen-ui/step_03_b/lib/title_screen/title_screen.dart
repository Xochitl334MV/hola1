// Copyright 2023 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import '../assets.dart';
import '../styles.dart';
import 'title_screen_ui.dart';

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> {
  Color get _emitColor =>
      AppColors.emitColors[_difficultyOverride ?? _difficulty];
  Color get _orbColor =>
      AppColors.orbColors[_difficultyOverride ?? _difficulty];

  int _difficulty = 0;
  int? _difficultyOverride;

  void _handleDifficultyPressed(int value) {
    setState(() => _difficulty = value);
  }

  void _handleDifficultyFocused(int? value) {
    setState(() => _difficultyOverride = value);
  }

  final _finalReceiveLightAmt = 0.7;
  final _finalEmitLightAmt = 0.5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Stack(
          children: [
            Image.asset(AssetPaths.titleBgBase),
            _buildLitImage(
              color: _orbColor,
              imgSrc: AssetPaths.titleBgReceive,
            ),
            IgnorePointer(
              child: Stack(
                children: [
                  _buildLitImage(
                    imgSrc: AssetPaths.titleMgBase,
                    color: _orbColor,
                  ),
                  _buildLitImage(
                    imgSrc: AssetPaths.titleMgReceive,
                    color: _orbColor,
                  ),
                  _buildLitImage(
                    imgSrc: AssetPaths.titleMgEmit,
                    emit: true,
                    color: _emitColor,
                  ),
                  Image.asset(AssetPaths.titleFgBase),
                  _buildLitImage(
                    imgSrc: AssetPaths.titleFgReceive,
                    color: _orbColor,
                  ),
                  _buildLitImage(
                    imgSrc: AssetPaths.titleFgEmit,
                    emit: true,
                    color: _emitColor,
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: TitleScreenUi(
                difficulty: _difficulty,
                onDifficultyFocused: _handleDifficultyFocused,
                onDifficultyPressed: _handleDifficultyPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLitImage(
      {required Color color, required String imgSrc, bool emit = false}) {
    final hsl = HSLColor.fromColor(color);
    final lightAmt = emit ? _finalEmitLightAmt : _finalReceiveLightAmt;

    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        hsl.withLightness(hsl.lightness * lightAmt).toColor(),
        BlendMode.modulate,
      ),
      child: Image.asset(imgSrc),
    );
  }
}
