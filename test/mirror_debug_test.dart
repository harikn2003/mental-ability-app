import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/engine/question_generator.dart';

void main() {
  test('mirror_text debug dump', () {
    for (int i = 0; i < 20; i++) {
      final q = QuestionGenerator.generate('mirror_text');
      print('\n--- MIRROR DEBUG #${i + 1} type=${q.type}');
      print('puzzle: ${q.puzzle}');
      print('correctIndex: ${q.correctIndex}');
      for (int j = 0; j < q.options.length; j++) {
        final o = q.options[j];
        print(
          '  opt[$j]: content=${o['content']} mirror_h=${o['mirror_h']} is_clock=${o['is_clock']}',
        );
      }
    }
  });
}
