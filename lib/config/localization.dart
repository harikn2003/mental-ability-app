class AppLocale {
  static final Map<String, Map<String, String>> _values = {
    'EN': {
      // ── Config Screen ────────────────────────────────────────────────────
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
      'start_weak': 'Start Weak Area Practice',
      'odd_man': 'Odd Man Out',
      'fig_match': 'Figure Match',
      'pattern': 'Pattern Compl.',
      'analogy': 'Analogy',
      'figure_match': 'Figure Match',
      'figure_series': 'Figure Series',
      'geo_completion': 'Geo Completion',
      'mirror_shape': 'Mirror Shape',
      'mirror_text': 'Mirror Text/Clock',
      'punch_hole': 'Punch Hole',
      'embedded': 'Embedded Figure',
      'practice_weak_card': 'Practice Weak Areas',
      'weak_topics': 'topics',
      'questions_label': 'questions',
      'hold_reset': 'Hold to reset progress',
      'reset_title': 'Reset progress?',
      'reset_body':
          'This will clear all saved bias weights and start fresh. Your weak area history will be lost.',
      'cancel': 'Cancel',
      'reset': 'Reset',

      // ── Quiz Screen ──────────────────────────────────────────────────────
      'find_the': 'FIND THE',
      'question_figure': 'Question Figure',
      'next_question': 'Next Question',
      'finish': 'Finish',
      'skip': 'Skip',
      'logic': 'Logic',
      'bias_weights': 'BIAS WEIGHTS',
      'show_bias': 'Coordinator: show bias chart',
      'hide_bias': 'Hide bias chart',
      'look_at': 'Look at Option...',
      'reviewing': 'Reviewing',
      'weak_area': 'Weak area',
      'times_up': "Time's up! Correct answer was Option",
      'skipped_msg': 'Skipped — correct answer is Option',
      'correct_msg': 'Correct! Well done.',
      'wrong_msg': 'Wrong — correct answer is Option',
      'skipped_count': 'skipped',

      // ── Topic labels for quiz header ─────────────────────────────────────
      'topic_pattern': 'PATTERN COMPLETION',
      'topic_mirror': 'MIRROR IMAGE',
      'topic_odd': 'ODD MAN OUT',
      'topic_analogy': 'ANALOGY',
      'topic_figmatch': 'FIGURE MATCH',
      'topic_series': 'FIGURE SERIES',
      'topic_geo': 'GEO COMPLETION',
      'topic_punch': 'PUNCH HOLE',
      'topic_embedded': 'EMBEDDED FIGURE',

      // ── Summary Screen ───────────────────────────────────────────────────
      'report_title': 'Session Summary',
      'score': 'Score',
      'accuracy': 'Accuracy',
      'time': 'Time',
      'performance': 'Performance by Topic',
      'correct': 'Correct',
      'incorrect': 'Incorrect',
      'analysis': 'Analysis',
      'home': 'Home',
      'practice_weak': 'Practice Weak Areas',
      'questions_correct': 'Questions Correct',
      'time_per_q': 'Time Per Question',
      'category_breakdown': 'Category Breakdown',
      'review_answers': 'Review Answers',
      'return_home': 'Return to Home',
      'no_weak_session': 'No Weak Areas This Session',
      'avg_per_q': 'Avg',
      'per_question': '/ question',

      // ── Review Screen ────────────────────────────────────────────────────
      'answer_review': 'Answer Review',
      'show_wrong': 'Show wrong answers only',
      'showing_wrong': 'Showing wrong answers — tap to show all',
      'all_correct': 'All answers were correct!',
      'no_wrong': 'No wrong answers to show.',
      'your_answer_right': 'Your answer ✓',
      'your_answer_wrong': 'Your answer',
      'list': 'List',

      // ── History Screen ───────────────────────────────────────────────────
      'session_history': 'Session History',
      'no_sessions': 'No sessions yet',
      'no_sessions_sub': 'Complete a quiz to see your history here.',
      'clear_history': 'Clear all history?',
      'clear_history_body':
          'All session records will be deleted. This cannot be undone.',
      'clear': 'Clear',
      'avg': 'avg',

      // ── Status labels ────────────────────────────────────────────────────
      'strong': 'Strong',
      'good': 'Good',
      'weak': 'Weak',
      'find_mirror': 'FIND THE MIRROR IMAGE',
      'find_match': 'FIND THE EXACT MATCH',
      'find_next': 'FIND THE NEXT FIGURE',
      'find_complete': 'COMPLETE THE FIGURE',
      'find_embedded': 'FIND THE EMBEDDED SHAPE',
      'find_unfolded': 'FIND THE UNFOLDED RESULT',
      'find_odd': 'FIND THE ODD ONE OUT',
      'no_detail_data': 'No question data for this session',
      'no_detail_data_sub':
          'Complete a new session to see full question review here.',
      // ── Category full names (summary/history) ────────────────────────────
      'cat_odd_man': 'Odd Man Out',
      'cat_fig_match': 'Figure Match',
      'cat_pattern': 'Pattern Completion',
      'cat_fig_series': 'Figure Series',
      'cat_analogy': 'Analogy',
      'cat_geo': 'Geo Completion',
      'cat_mirror_shape': 'Mirror Shape',
      'cat_mirror_text': 'Mirror Text',
      'cat_punch': 'Punch Hole',
      'cat_embedded': 'Embedded Figure',

      // ── Category short labels (history bar chart) ─────────────────────────
      'short_odd': 'Odd',
      'short_fig': 'Fig',
      'short_pattern': 'Pat',
      'short_series': 'Ser',
      'short_analogy': 'Ana',
      'short_geo': 'Geo',
      'short_mirshape': 'MirS',
      'short_mirtext': 'MirT',
      'short_punch': 'Pnc',
      'short_embedded': 'Emb',

      // ── Misc UI ───────────────────────────────────────────────────────────
      'time_unlimited': 'Unlimited',
      'time_label': 'Time',
      'weak_areas': 'Weak Areas',
      'clear_history_btn': 'Clear history',

      // ── Question renderer instructions ────────────────────────────────────
      'instr_match': 'Find the exact match',
      'instr_pattern': 'Find the missing figure to complete the pattern',
      'instr_series': 'What comes next in the series?',
      'instr_geo': 'Which piece completes this shape?',
      'instr_mirror': 'Find the mirror image',
      'instr_embedded':
          'Find the option that contains this shape hidden inside it',
      'instr_analogy': 'A : B :: C : ?  — Find D',
      'instr_error': 'Unable to generate — please skip this question.',
    },

    'MR': {
      // ── Config Screen ────────────────────────────────────────────────────
      'title': 'नवीन सत्र',
      'total_questions': 'एकूण प्रश्न',
      'time_per_question': 'प्रत्येक प्रश्नासाठी वेळ',
      'select_mode': 'विषय निवडा',
      'random_mix': 'मिश्र सराव',
      'random_desc': 'सर्व विषयांमधील प्रश्नांचा समावेश आहे.',
      'intelligent_bias': 'बुद्धिमान निवड',
      'bias_sub': 'कमकुवत क्षेत्रांवर लक्ष',
      'start_random': 'मिश्र सराव सुरू करा',
      'start_linear': 'रेखीय चाचणी सुरू करा',
      'start_weak': 'कमकुवत विषयांचा सराव सुरू करा',
      'odd_man': 'वेगळे पद ओळखा',
      'fig_match': 'समान आकृती',
      'pattern': 'आकृती पूर्ण करा',
      'analogy': 'समसंबंध',
      'figure_match': 'समान आकृती',
      'figure_series': 'आकृती मालिका',
      'geo_completion': 'भौमितिक पूर्तता',
      'mirror_shape': 'आरसा प्रतिमा',
      'mirror_text': 'अक्षर / घड्याळ आरसा',
      'punch_hole': 'छिद्र आकृती',
      'embedded': 'अंतर्भूत आकृती',
      'practice_weak_card': 'कमकुवत विषयांचा सराव',
      'weak_topics': 'विषय',
      'questions_label': 'प्रश्न',
      'hold_reset': 'प्रगती रीसेट करण्यासाठी दीर्घ दाबा',
      'reset_title': 'प्रगती रीसेट करायची का?',
      'reset_body':
          'यामुळे सर्व बायस वेट मिटतील आणि नव्याने सुरुवात होईल. कमकुवत विषयांचा इतिहास नष्ट होईल.',
      'cancel': 'रद्द करा',
      'reset': 'रीसेट',

      // ── Quiz Screen ──────────────────────────────────────────────────────
      'find_the': 'खालीलपैकी ओळखा',
      'question_figure': 'प्रश्न आकृती',
      'next_question': 'पुढचा प्रश्न',
      'finish': 'संपवा',
      'skip': 'वगळा',
      'logic': 'स्पष्टीकरण',
      'bias_weights': 'बायस वेट',
      'show_bias': 'समन्वयक: बायस चार्ट दाखवा',
      'hide_bias': 'बायस चार्ट लपवा',
      'look_at': 'पर्याय पाहा...',
      'reviewing': 'पुनरावलोकन',
      'weak_area': 'कमकुवत विषय',
      'times_up': 'वेळ संपला! बरोबर उत्तर पर्याय',
      'skipped_msg': 'वगळले — बरोबर उत्तर पर्याय',
      'correct_msg': 'बरोबर! शाबास.',
      'wrong_msg': 'चुकीचे — बरोबर उत्तर पर्याय',
      'skipped_count': 'वगळलेले',

      // ── Topic labels ─────────────────────────────────────────────────────
      'topic_pattern': 'आकृती पूर्णता',
      'topic_mirror': 'आरसा प्रतिमा',
      'topic_odd': 'वेगळे पद',
      'topic_analogy': 'समसंबंध',
      'topic_figmatch': 'समान आकृती',
      'topic_series': 'आकृती मालिका',
      'topic_geo': 'भौमितिक पूर्तता',
      'topic_punch': 'छिद्र आकृती',
      'topic_embedded': 'अंतर्भूत आकृती',

      // ── Summary Screen ───────────────────────────────────────────────────
      'report_title': 'सत्र सारांश',
      'score': 'गुण',
      'accuracy': 'अचूकता',
      'time': 'वेळ',
      'performance': 'विषयानुसार कामगिरी',
      'correct': 'बरोबर',
      'incorrect': 'चूक',
      'analysis': 'विश्लेषण',
      'home': 'मुख्य पृष्ठ',
      'practice_weak': 'कमकुवत विषयांचा सराव',
      'questions_correct': 'प्रश्न बरोबर',
      'time_per_q': 'प्रति प्रश्न वेळ',
      'category_breakdown': 'विषयनिहाय विश्लेषण',
      'review_answers': 'उत्तरे तपासा',
      'return_home': 'मुख्यपृष्ठावर परत',
      'no_weak_session': 'या सत्रात कोणते कमकुवत विषय नाहीत',
      'avg_per_q': 'सरासरी',
      'per_question': '/ प्रश्न',

      // ── Review Screen ────────────────────────────────────────────────────
      'answer_review': 'उत्तर तपासणी',
      'show_wrong': 'फक्त चुकीची उत्तरे दाखवा',
      'showing_wrong': 'चुकीची उत्तरे दाखवत आहे — सर्व पाहण्यासाठी दाबा',
      'all_correct': 'सर्व उत्तरे बरोबर होती!',
      'no_wrong': 'दाखवण्यासारखी चुकीची उत्तरे नाहीत.',
      'your_answer_right': 'तुमचे उत्तर ✓',
      'your_answer_wrong': 'तुमचे उत्तर',
      'list': 'यादी',

      // ── History Screen ───────────────────────────────────────────────────
      'session_history': 'सत्र इतिहास',
      'no_sessions': 'अद्याप कोणते सत्र नाही',
      'no_sessions_sub': 'इतिहास पाहण्यासाठी एक चाचणी पूर्ण करा.',
      'clear_history': 'सर्व इतिहास मिटवायचा का?',
      'clear_history_body': 'सर्व सत्र नोंदी कायमस्वरूपी हटवल्या जातील.',
      'clear': 'मिटवा',
      'avg': 'सरासरी',

      // ── Status labels ────────────────────────────────────────────────────
      'strong': 'उत्तम',
      'good': 'चांगले',
      'weak': 'कमकुवत',
      'find_mirror': 'आरसा प्रतिमा शोधा',
      'find_match': 'समान आकृती शोधा',
      'find_next': 'पुढील आकृती शोधा',
      'find_complete': 'आकृती पूर्ण करा',
      'find_embedded': 'अंतर्भूत आकृती शोधा',
      'find_unfolded': 'उघडलेली आकृती शोधा',
      'find_odd': 'वेगळी आकृती शोधा',
      'no_detail_data': 'या सत्रासाठी प्रश्नांचा डेटा उपलब्ध नाही',
      'no_detail_data_sub': 'पूर्ण प्रश्न पुनरावलोकनासाठी नवीन सत्र पूर्ण करा.',
      // ── Category full names ───────────────────────────────────────────────
      'cat_odd_man': 'वेगळे पद',
      'cat_fig_match': 'समान आकृती',
      'cat_pattern': 'आकृती पूर्णता',
      'cat_fig_series': 'आकृती मालिका',
      'cat_analogy': 'समसंबंध',
      'cat_geo': 'भौमितिक पूर्तता',
      'cat_mirror_shape': 'आरसा आकृती',
      'cat_mirror_text': 'अक्षर आरसा',
      'cat_punch': 'छिद्र आकृती',
      'cat_embedded': 'अंतर्भूत आकृती',

      // ── Category short labels ─────────────────────────────────────────────
      'short_odd': 'वेग',
      'short_fig': 'आकृ',
      'short_pattern': 'पूर्ण',
      'short_series': 'माल',
      'short_analogy': 'सम',
      'short_geo': 'भौ',
      'short_mirshape': 'आर',
      'short_mirtext': 'अक्ष',
      'short_punch': 'छिद्र',
      'short_embedded': 'अंत',

      // ── Misc UI ───────────────────────────────────────────────────────────
      'time_unlimited': 'अमर्यादित',
      'time_label': 'वेळ',
      'weak_areas': 'कमकुवत विषय',
      'clear_history_btn': 'इतिहास मिटवा',

      // ── Question renderer instructions ────────────────────────────────────
      'instr_match': 'अचूक जुळणारी आकृती शोधा',
      'instr_pattern': 'आकृती पूर्ण करण्यासाठी चुकलेली आकृती शोधा',
      'instr_series': 'मालिकेत पुढे काय येते?',
      'instr_geo': 'कोणता तुकडा ही आकृती पूर्ण करतो?',
      'instr_mirror': 'आरसा प्रतिमा शोधा',
      'instr_embedded': 'या आकृतीला आतमध्ये लपवणारा पर्याय शोधा',
      'instr_analogy': 'A : B :: C : ?  — D शोधा',
      'instr_error': 'प्रश्न तयार करता आला नाही — हा प्रश्न वगळा.',
    },
  };

  static String get(String lang, String key) {
    return _values[lang]?[key] ?? _values['EN']?[key] ?? key;
  }

  static String nextLang(String current) {
    const cycle = ['EN', 'MR'];
    final idx = cycle.indexOf(current);
    return cycle[(idx + 1) % cycle.length];
  }

  static String langLabel(String lang) {
    const labels = {'EN': 'EN', 'MR': 'मर'};
    return labels[lang] ?? lang;
  }

  // ── App-wide current language ───────────────────────────────────────────
  // Set this when user changes language in SessionConfigScreen.
  // All screens that don't receive lang explicitly can read from here.
  static String _current = 'EN';

  static String get current => _current;

  static void setLang(String lang) {
    if (_values.containsKey(lang)) _current = lang;
  }

  /// Shorthand — AppLocale.s('key') uses the app-wide current language
  static String s(String key) => get(_current, key);
}