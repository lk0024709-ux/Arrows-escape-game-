import 'package:flutter/material.dart';

/// Central theme palette shared across the whole app so screens stay in sync.
///
/// Moved here from `main.dart` so the game screen and its widgets can all
/// reference the same colours without duplicating constants.
const Color kInk = Color(0xFF07164F);
const Color kAccent = Color(0xFF2585FF);
const Color kDanger = Color(0xFFEF4444);
const Color kMuted = Color(0xFFD9DEE8);

/// Colour used to distinguish God levels (level number > 100).
const Color kGod = Color(0xFF7C3AED);

/// Colour used to distinguish Boss levels (level number > 200).
const Color kBoss = Color(0xFF0F766E);
