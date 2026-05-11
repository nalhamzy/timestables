// Design tokens for Times Tables Trainer.
// ui-ux-designer fills in the final values. These are the architect's defaults.
// Light mode only — dark mode is explicitly excluded (SPEC §10 item 2).

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Primary palette — calm, trustworthy, high-contrast, kid-accessible
// ---------------------------------------------------------------------------

/// Primary blue — nav bar, CTA buttons, progress rings
const Color kPrimary = Color(0xFF1565C0);

/// Accent green — "Got it" / correct answer feedback, mastered badge
const Color kAccentGreen = Color(0xFF2E7D32);

/// Accent red — "Not yet" / wrong answer feedback
const Color kAccentRed = Color(0xFFB71C1C);

/// Amber — "Keep going" mastery status (40–79% accuracy)
const Color kAccentAmber = Color(0xFFF57F17);

/// Background — main scaffold colour
const Color kBackground = Color(0xFFF8FBFF);

/// Card surface
const Color kCard = Color(0xFFFFFFFF);

/// Body text
const Color kInk = Color(0xFF1A1A2E);

/// Secondary / label text
const Color kInkSoft = Color(0xFF546E7A);

/// Dividers and hairlines
const Color kHairline = Color(0xFFCFD8DC);

/// Lock icon overlay on premium table cards
const Color kLockOverlay = Color(0x99000000);

// ---------------------------------------------------------------------------
// Typography scale
// ---------------------------------------------------------------------------

/// Equation display in Flash and Practice screens
const double kEquationFontSize = 52.0;

/// Answer revealed on flash card back
const double kAnswerFontSize = 64.0;

/// Table card label (e.g. "7×")
const double kTableLabelFontSize = 28.0;

/// Body / UI text
const double kBodyFontSize = 16.0;

// ---------------------------------------------------------------------------
// Spacing and sizing
// ---------------------------------------------------------------------------

/// Minimum tap target — 48×48 logical pixels (accessibility + kids UX)
const double kMinTapTarget = 48.0;

/// Number pad key height
const double kNumPadKeyHeight = 64.0;

/// Card corner radius
const double kCardRadius = 16.0;

/// Standard horizontal page padding
const double kPagePadding = 20.0;
