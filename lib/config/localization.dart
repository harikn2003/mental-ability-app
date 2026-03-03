class AppLocale {
  static final Map<String, Map<String, String>> _values = {
    'EN': {
      // Config Screen
      'title': 'New Session',
      'total_questions': 'TOTAL QUESTIONS',
      'time_per_question': 'TIME PER QUESTION',
      'select_mode': 'SELECT MODE / TOPIC',
      'random_mix': 'Random Mix',
      'random_desc': 'Includes questions from all categories.',
      'intelligent_bias': 'Intelligent Bias',
      'bias_sub': 'Focus on weak areas',
      'start_random': 'Start Random Challenge',
      'start_linear': 'Start Linear Test',
      'odd_man': 'Odd Man Out',
      'fig_match': 'Figure Match',
      'pattern': 'Pattern Compl.',
      'analogy': 'Analogy',

      // Quiz Screen
      'find_the': 'FIND THE',
      'question_figure': 'Question Figure',
      'next_question': 'Next Question',
      'logic': 'Logic',

      // Summary Screen
      'report_title': 'Session Report',
      'score': 'Score',
      'accuracy': 'Accuracy',
      'time': 'Time',
      'performance': 'Performance by Topic',
      'correct': 'Correct',
      'incorrect': 'Incorrect',
      'analysis': 'Analysis',
      'home': 'Home',
      'practice_weak': 'Practice Weak Areas',
    },
    'MR': {
      // Config Screen
      'title': 'नवीन सत्र',
      'total_questions': 'एकूण प्रश्न',
      'time_per_question': 'प्रत्येक प्रश्नासाठी वेळ',
      'select_mode': 'विषय निवडा',
      'random_mix': 'मिश्र सराव',
      'random_desc': 'सर्व विषयांमधील प्रश्नांचा समावेश आहे.',
      'intelligent_bias': 'बुद्धिमान निवड',
      'bias_sub': 'कमकुवत क्षेत्रांवर लक्ष',
      'start_random': 'सराव सुरू करा',
      'start_linear': 'चाचणी सुरू करा',
      'odd_man': 'वेगळे पद ओळखा',
      'fig_match': 'समान आकृती',
      'pattern': 'आकृती पूर्ण करा',
      'analogy': 'समसंबंध',

      // Quiz Screen
      'find_the': 'खालीलपैकी ओळखा',
      'question_figure': 'प्रश्न आकृती',
      'next_question': 'पुढचा प्रश्न',
      'logic': 'स्पष्टीकरण',

      // Summary Screen
      'report_title': 'चाचणी अहवाल',
      'score': 'गुण',
      'accuracy': 'अचूकता',
      'time': 'वेळ',
      'performance': 'विषयानुसार कामगिरी',
      'correct': 'बरोबर',
      'incorrect': 'चूक',
      'analysis': 'विश्लेषण',
      'home': 'मुख्य पृष्ठ',
      'practice_weak': 'सराव करा',
    },
  };

  // Helper function to get text
  static String get(String lang, String key) {
    return _values[lang]?[key] ??
        key; // Returns English key if translation missing
  }
}
