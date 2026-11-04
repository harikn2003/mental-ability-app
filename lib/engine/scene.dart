import 'dart:ui' show Color, Offset, Size;

import 'morph.dart';

/// An answer explanation acted out on the question's own figures: figure
/// slots laid out like the question, and steps played one after another.
/// Pure data; `ScenePlayer` draws it.
class Scene {
  /// The layout box, in logical pixels (the player scales it down to fit).
  final Size extent;
  final List<Slot> slots;
  final List<SceneStep> steps;

  /// The slot that ends holding the correct option (framed green).
  final int answerSlot;

  const Scene({required this.extent, required this.slots, required this.steps, required this.answerSlot});

  double get totalWeight => steps.fold(0.0, (s, x) => s + x.weight);

  /// About 0.8 s per step, at least 3 s, at most 6.5 s.
  Duration get duration => Duration(milliseconds: (1000 * (0.9 + 0.8 * totalWeight)).clamp(3000, 6500).round());

  /// What each slot holds after all steps have played.
  List<Map<String, dynamic>?> get finalContents {
    final c = [for (final s in slots) s.figure];
    for (final step in steps) {
      step.apply(c);
    }
    return c;
  }
}

class Slot {
  /// What the slot shows at the start; null with [question] = the grey "?".
  final Map<String, dynamic>? figure;

  /// Top-left corner within [Scene.extent].
  final Offset at;
  final double size;

  /// A question box: grey with "?" until a step fills it.
  final bool question;

  const Slot({this.figure, required this.at, this.size = 64, this.question = false});
}

/// One step of a scene; [weight] is its share of the time.
sealed class SceneStep {
  final double weight;
  const SceneStep({this.weight = 1});

  /// Updates the slot contents as they are after this step.
  void apply(List<Map<String, dynamic>?> contents) {}
}

/// The figure in [slot] changes in place, beat by beat.
class MorphStep extends SceneStep {
  final int slot;
  final List<Beat> beats;
  const MorphStep(this.slot, this.beats, {super.weight});

  @override
  void apply(List<Map<String, dynamic>?> contents) {
    if (beats.isNotEmpty) contents[slot] = beats.last.to;
  }
}

/// A copy of [figure] (by default what [from] holds) flies from slot [from]
/// to slot [to], playing [beats] on the way; [to] then holds the result, or
/// [land] when the copy lands on something it adds to (e.g. two cells
/// flying into one, which then holds both).
class FlyStep extends SceneStep {
  final int from, to;
  final List<Beat> beats;
  final Map<String, dynamic>? figure, land;
  const FlyStep(this.from, this.to, this.beats, {this.figure, this.land, super.weight});

  Map<String, dynamic>? result(List<Map<String, dynamic>?> c) => land ?? (beats.isNotEmpty ? beats.last.to : (figure ?? c[from]));

  @override
  void apply(List<Map<String, dynamic>?> contents) => contents[to] = result(contents);
}

/// The [slots] glow in [colour]; with [stay] they keep the outline after.
class PulseStep extends SceneStep {
  final List<int> slots;
  final Color colour;
  final bool stay;
  const PulseStep(this.slots, {this.colour = const Color(0xFF16A34A), this.stay = false, super.weight});
}

/// [count] tick marks appear one by one under [slot] (counting without
/// digits); they stay.
class TickStep extends SceneStep {
  final int slot, count;
  final Color colour;
  const TickStep(this.slot, this.count, {this.colour = const Color(0xFF195DE6), super.weight});
}

/// Several steps at the same time (e.g. every option counted at once).
class TogetherStep extends SceneStep {
  final List<SceneStep> steps;
  const TogetherStep(this.steps, {super.weight});

  @override
  void apply(List<Map<String, dynamic>?> contents) {
    for (final s in steps) {
      s.apply(contents);
    }
  }
}

/// Last step: the answer slot is framed green.
class RevealStep extends SceneStep {
  const RevealStep({super.weight = 0.6});
}
