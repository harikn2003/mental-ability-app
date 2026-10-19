// The session shows a topic under the same name as the config screen
// (tracker: both mirror topics showed as "Mirror image" in a session).

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/config/localization.dart';

void main() {
  const topics = ['odd_man', 'figure_match', 'pattern', 'figure_series', 'analogy', 'geo_completion',
      'mirror_shape', 'mirror_text', 'punch_hole', 'embedded', 'space_vis'];

  test('every topic has its own name in every language', () {
    for (final lang in ['EN', 'MR', 'HI']) {
      final names = [for (final t in topics) AppLocale.topicName(lang, t)];
      expect(names.toSet(), hasLength(topics.length), reason: '$lang: $names');
    }
  });

  test('the two mirror topics are named as on the config screen', () {
    expect(AppLocale.topicName('EN', 'mirror_shape'), 'Mirror Shape');
    expect(AppLocale.topicName('EN', 'mirror_text'), 'Mirror Text');
  });
}
