# NplusPrep — Mental Ability Trainer

![Flutter](https://img.shields.io/badge/Flutter-3.29%2B-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.8%2B-0175C2?logo=dart)
![Platform](https://img.shields.io/badge/Platform-Android%2012%2B-green)
![Offline](https://img.shields.io/badge/Network-Offline--first-brightgreen)

An offline-first adaptive learning app for students preparing for competitive exams — Navodaya (5th
Grade), IBPS, UPSC, and Police recruitment. Built as part of the IIT Madras WSAI internship.

## Overview

NplusPrep is a digital mental ability trainer that adapts to each student's weaknesses in real time.
Unlike static practice papers, it uses an **Intelligent Bias** engine that detects incorrect answers
and automatically increases the frequency of those question categories in subsequent rounds.

The app runs entirely offline — no internet connection required at any point. All question
generation, scoring, and session logging happens on-device.

## Features

- **10 Question Categories** — Odd Man Out, Figure Match, Pattern Completion, Figure Series,
  Analogy, Geo Completion, Mirror Shape, Mirror Text/Clock, Punch Hole, Embedded Figure
- **Intelligent Bias Engine** — wrong answers increase that category's weight; correct answers
  reduce it. Weights update after every answer so the very next question reflects performance
- **Two Modes** — Linear (coordinator picks one category for focused practice) and Random (adaptive
  mix across all categories)
- **Programmable Timer** — 30s / 2 minutes / Unlimited per question, with a countdown pulse
  animation
- **Multilingual** — English and Marathi (Hindi planned)
- **Session Review** — after every session, view every question with correct/wrong options
  highlighted, filter to wrong answers only
- **Coordinator Tools** — bias weight chart shows which topics are being focused on; session review
  lets coordinators identify specific student weaknesses
- **Haptic Feedback** — distinct patterns for correct (light) and wrong (double medium) answers
- **A/B/C/D Labels** — options are always clearly labelled; result feedback says "correct answer is
  Option B" not a number

## Tech Stack

| Layer              | Choice                | Reason                                                                        |
|--------------------|-----------------------|-------------------------------------------------------------------------------|
| Framework          | Flutter (Dart)        | Single codebase, high-performance Canvas rendering for figure drawing         |
| Question Rendering | Flutter CustomPainter | All 10 question types drawn programmatically — no image assets, fully offline |
| State              | setState + in-memory  | No external state library needed for this scope                               |
| Charts             | fl_chart              | Session summary bar/pie charts                                                |
| Fonts              | google_fonts          | Lexend for readability                                                        |

## Architecture

```
lib/
  config/         localization.dart          — EN + MR strings
  engine/
    question_generator.dart                  — all 10 question generators + bias-aware _key()
    question_attempt.dart                    — per-question result model
    reasoning_question.dart                  — question data model
  painters/
    figure_painter.dart                      — unified shape painter (shapes 0-8)
    mirror_text_painter.dart                 — letter/digit/clock mirror painter
    punch_painter.dart                       — folded paper punch hole painter
  screens/
    session_config_screen.dart               — mode, topic, time, count selection
    quiz_screen.dart                         — question flow, timer, bias engine
    session_summary_screen.dart              — score, time chart, category breakdown
    session_review_screen.dart               — per-question review with filter
  widgets/
    question_renderer.dart                   — puzzle area renderer for all 10 types
    option_renderer.dart                     — option card renderer, dispatches by type
```

## Question Design

All shapes are drawn by a single `FigurePainter` using a shared vocabulary (shape codes 0–8: circle,
square, triangle, diamond, cross, pentagon, hexagon, arrow, L-shape). This ensures every question
type and every option card uses exactly the same visual language.

Distractors are pedagogically designed per question type — they represent specific reasoning
mistakes rather than random shapes. For example, punch hole wrong options show: the correct axis
mirrored on the wrong axis, a double-fold result with 4 holes, and a single un-mirrored hole (
forgetting that unfolding doubles the hole).

## Beta Release (GitHub)

- Version format: `x.y.z-beta.n+build` in `pubspec.yaml`
- Tag format: `vx.y.z-beta.n`
- Pushing a beta tag triggers `.github/workflows/beta-release.yml`
- Workflow validates tag version against `pubspec.yaml` build-name
- GitHub release is published as a **pre-release** with APK and AAB artifacts

See `docs/release_beta.md` for the full checklist and commands.
