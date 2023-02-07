// Copyright 2022 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/animation.dart';

class RailFabAnimation extends CurvedAnimation {
  RailFabAnimation({required super.parent})
      : super(
          curve: const Interval(3 / 5, 1),
        );
}
