import 'package:flutter/material.dart';
import 'package:mental_ability_app/config/localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quiz_screen.dart';
import 'session_history_screen.dart';

class SessionConfigScreen extends StatefulWidget {
  const SessionConfigScreen({super.key});

  @override
  State<SessionConfigScreen> createState() => _SessionConfigScreenState();
}

class _SessionConfigScreenState extends State<SessionConfigScreen> {
  // --- STATE VARIABLES ---
  int selectedCount = 10;
  String selectedTime = '2m';
  String selectedMode = 'random'; // 'random' or 'odd_man', etc.
  bool isBiasEnabled = true;
  String currentLang = 'EN';

  // --- THEME COLORS ---
  static const Color primary = Color(0xFF195DE6);
  static const Color primaryDark = Color(0xFF144AC0);
  static const Color primaryLight = Color(0xFFEEF4FF);
  static const Color surface = Colors.white;
  static const Color background = Color(0xFFF6F6F8);
  static const Color textMain = Color(0xFF0F172A);
  static const Color textSubtle = Color(0xFF64748B);
  static const Color accentOrange = Color(0xFFF97316);
  static const Color accentEmerald = Color(0xFF10B981);
  static const Color accentPurple = Color(0xFFA855F7);

  // Persisted bias weights loaded from SharedPreferences
  // Passed into QuizScreen so the session starts from where the student left off
  Map<String, int> _savedWeights = {};

  static const _kWeightsKey = 'bias_weights';
  static const _defaultCategories = [
    'pattern', 'analogy', 'odd_man', 'mirror_shape', 'figure_match',
    'figure_series', 'geo_completion', 'mirror_text', 'punch_hole', 'embedded',
  ];

  Map<String, String> get _categoryLabels =>
      {
        'pattern': AppLocale.get(currentLang, 'cat_pattern'),
        'analogy': AppLocale.get(currentLang, 'cat_analogy'),
        'odd_man': AppLocale.get(currentLang, 'cat_odd_man'),
        'mirror_shape': AppLocale.get(currentLang, 'cat_mirror_shape'),
        'figure_match': AppLocale.get(currentLang, 'cat_fig_match'),
        'figure_series': AppLocale.get(currentLang, 'cat_fig_series'),
        'geo_completion': AppLocale.get(currentLang, 'cat_geo'),
        'mirror_text': AppLocale.get(currentLang, 'cat_mirror_text'),
        'punch_hole': AppLocale.get(currentLang, 'cat_punch'),
        'embedded': AppLocale.get(currentLang, 'cat_embedded'),
  };

  // Categories with weight > 1 are considered weak
  List<MapEntry<String, int>> get _weakCategories =>
      _savedWeights.entries
          .where((e) => e.value > 1)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value)); // highest weight first

  @override
  void initState() {
    super.initState();
    _loadSavedWeights();
  }

  Future<void> _loadSavedWeights() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = <String, int>{};
    for (final cat in _defaultCategories) {
      saved[cat] = prefs.getInt('${_kWeightsKey}_$cat') ?? 1;
    }
    if (mounted) setState(() => _savedWeights = saved);
  }

  Future<void> _resetWeights() async {
    final prefs = await SharedPreferences.getInstance();
    for (final cat in _defaultCategories) {
      await prefs.setInt('${_kWeightsKey}_$cat', 1);
    }
    if (mounted) {
      setState(() =>
      _savedWeights = {
        for (final cat in _defaultCategories) cat: 1,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER & SETTINGS
            _buildHeader(),

            // 2. SCROLLABLE CONTENT
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocale.get(currentLang, 'select_mode'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textSubtle,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // RANDOM MIX CARD (Hero)
                    _buildRandomCard(),

                    // WEAK AREAS CARD — only shown when student has weak spots
                    if (_weakCategories.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildWeakAreasCard(),
                    ],

                    const SizedBox(height: 16),

                    // TOPIC GRID — all 10 topics
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _buildTopicCard(id: 'odd_man',
                            title: AppLocale.get(currentLang, 'odd_man'),
                            icon: Icons.grid_view,
                            color: primary),
                        _buildTopicCard(id: 'figure_match',
                            title: AppLocale.get(currentLang, 'fig_match'),
                            icon: Icons.join_inner,
                            color: accentOrange),
                        _buildTopicCard(id: 'pattern',
                            title: AppLocale.get(currentLang, 'pattern'),
                            icon: Icons.texture,
                            color: accentEmerald),
                        _buildTopicCard(id: 'figure_series',
                            title: AppLocale.get(currentLang, 'figure_series'),
                            icon: Icons.trending_flat,
                            color: accentPurple),
                        _buildTopicCard(id: 'analogy',
                            title: AppLocale.get(currentLang, 'analogy'),
                            icon: Icons.compare_arrows,
                            color: const Color(0xFF14B8A6)),
                        _buildTopicCard(id: 'geo_completion',
                            title: AppLocale.get(currentLang, 'geo_completion'),
                            icon: Icons.change_history,
                            color: const Color(0xFFF59E0B)),
                        _buildTopicCard(id: 'mirror_shape',
                            title: AppLocale.get(currentLang, 'mirror_shape'),
                            icon: Icons.flip,
                            color: const Color(0xFFF43F5E)),
                        _buildTopicCard(id: 'mirror_text',
                            title: AppLocale.get(currentLang, 'mirror_text'),
                            icon: Icons.text_fields,
                            color: accentOrange),
                        _buildTopicCard(id: 'punch_hole',
                            title: AppLocale.get(currentLang, 'punch_hole'),
                            icon: Icons.radio_button_unchecked,
                            color: accentEmerald),
                        _buildTopicCard(id: 'embedded',
                            title: AppLocale.get(currentLang, 'embedded'),
                            icon: Icons.center_focus_strong,
                            color: const Color(0xFF14B8A6)),
                      ],
                    ),
                    const SizedBox(height: 100), // Spacing for sticky footer
                  ],
                ),
              ),
            ),

            // 3. STICKY FOOTER
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      color: background,
      child: Column(
        children: [
          // Top Row: Title + Language
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocale.get(currentLang, 'title'),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textMain,
                  fontFamily: 'Lexend',
                ),
              ),
              Row(
                children: [
                  // History button
                  GestureDetector(
                    onTap: () =>
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SessionHistoryScreen()),
                        ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(20),
                        border:
                        Border.all(color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.history_rounded,
                          color: primary, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Language toggle
                  GestureDetector(
                    onTap: () =>
                        setState(() {
                          currentLang = AppLocale.nextLang(currentLang);
                          AppLocale.setLang(currentLang);
                        }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.grey.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.translate,
                              color: primary, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            AppLocale.langLabel(currentLang),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Setting 1: Total Questions — slider from 10 to 50, step 10
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.format_list_numbered, size: 18, color: primary),
                  const SizedBox(width: 8),
                  Text(
                    AppLocale.get(currentLang, 'total_questions').toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold,
                      color: textSubtle,
                    ),
                  ),
                  const Spacer(),
                  // Current value badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$selectedCount ${AppLocale.get(
                          currentLang, "questions_label")}',
                      style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: primary,
                  inactiveTrackColor: Colors.grey.shade200,
                  thumbColor: primary,
                  overlayColor: primary.withOpacity(0.1),
                  trackHeight: 4,
                  showValueIndicator: ShowValueIndicator.never,
                ),
                child: Slider(
                  min: 10,
                  max: 50,
                  divisions: 4,
                  // 10, 20, 30, 40, 50
                  value: selectedCount.toDouble(),
                  onChanged: (v) =>
                      setState(() => selectedCount = v.round()),
                ),
              ),
              // Tick labels
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['10', '20', '30', '40', '50']
                      .map((l) =>
                      Text(l,
                          style: TextStyle(
                            fontSize: 10,
                            color: selectedCount == int.parse(l)
                                ? primary
                                : textSubtle,
                            fontWeight: selectedCount == int.parse(l)
                                ? FontWeight.bold
                                : FontWeight.normal,
                          )))
                      .toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Setting 2: Time Per Question
          _buildSettingRow(
            icon: Icons.timer_outlined,
            label: AppLocale.get(currentLang, 'time_per_question'),
            children: ['30s', '2m', 'unlimited']
                .map(
                  (val) => _buildChip(
                    label: val == 'unlimited'
                        ? AppLocale.get(currentLang, 'time_unlimited')
                        : val,
                    isSelected: selectedTime == val,
                    onTap: () => setState(() => selectedTime = val),
                  ),
            )
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildWeakAreasCard() {
    final weak = _weakCategories;
    final isSelected = selectedMode == 'weak_areas';

    // Colour-code pills by severity: weight 2-3=amber, 4-6=orange, 7+=red
    Color pillColor(int weight) {
      if (weight >= 7) return const Color(0xFFEF4444);
      if (weight >= 4) return const Color(0xFFF97316);
      return const Color(0xFFF59E0B);
    }

    return GestureDetector(
      onTap: () => setState(() => selectedMode = 'weak_areas'),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (_) =>
              AlertDialog(
                title: Text(AppLocale.get(currentLang, 'reset_title')),
                content: Text(AppLocale.get(currentLang, 'reset_body')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(AppLocale.get(currentLang, 'cancel')),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _resetWeights();
                    },
                    child: Text(
                      AppLocale.get(currentLang, 'reset'),
                      style: TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF7ED) : surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFF97316)
                : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFFEDD5)
                    : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.fitness_center_rounded,
                color: const Color(0xFFF97316),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        AppLocale.get(currentLang, 'practice_weak_card'),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: textMain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Count badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${weak.length} ${AppLocale.get(
                              currentLang, "weak_topics")}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Weak category pills — sorted by severity
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: weak.map((e) {
                      final color = pillColor(e.value);
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: color.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _categoryLabels[e.key] ?? e.key,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Strength bar — 1 to 5 dots representing weight
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                ((e.value - 1) / 2).ceil().clamp(1, 5),
                                    (_) =>
                                    Container(
                                      width: 4, height: 4,
                                      margin: const EdgeInsets.only(left: 2),
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocale.get(currentLang, 'hold_reset'),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 14),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRandomCard() {
    bool isSelected = selectedMode == 'random';

    return GestureDetector(
      onTap: () => setState(() => selectedMode = 'random'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primary, Color(0xFF0B3DA8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: isSelected ? Border.all(color: primaryLight, width: 4) : null,
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocale.get(currentLang, 'random_mix'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontFamily: 'Lexend',
                      ),
                    ),
                  ],
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: primary, size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              AppLocale.get(currentLang, 'random_desc'),
              style: const TextStyle(color: primaryLight, fontSize: 13),
            ),
            const SizedBox(height: 16),

            // INTELLIGENT BIAS TOGGLE
            GestureDetector(
              onTap: () => setState(() => isBiasEnabled = !isBiasEnabled),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    // Custom Switch
                    Container(
                      width: 44,
                      height: 26,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: isBiasEnabled
                            ? accentEmerald
                            : Colors.grey.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Align(
                        alignment: isBiasEnabled
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocale.get(currentLang, 'intelligent_bias'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          AppLocale.get(currentLang, 'bias_sub'),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicCard({
    required String id,
    required String title,
    required IconData icon,
    required Color color,
  }) {
    bool isSelected = selectedMode == id;

    return GestureDetector(
      onTap: () => setState(() => selectedMode = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? primaryLight : surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: isSelected ? primary : color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MISSING HELPERS ADDED HERE ---

  Widget _buildSettingRow({
    required IconData icon,
    required String label,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: primary),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textSubtle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(children: children),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? primary : surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primary : Colors.grey.withOpacity(0.3),
            ),
            boxShadow: isSelected
                ? [
              BoxShadow(
                color: primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ]
                : [],
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : textSubtle,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface.withOpacity(0.9),
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: () {
            // weak_areas mode: random session using only the weak categories,
            // with weights proportional to how weak each one is
            if (selectedMode == 'weak_areas') {
              final weakWeights = <String, int>{
                for (final e in _weakCategories) e.key: e.value,
              };
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      QuizScreen(
                        mode: 'random',
                        totalQuestions: selectedCount,
                        timePerQuestion: selectedTime,
                        biasEnabled: true,
                        initialWeights: weakWeights,
                      ),
                ),
              );
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuizScreen(
                  mode: selectedMode,
                  totalQuestions: selectedCount,
                  timePerQuestion: selectedTime,
                  biasEnabled: isBiasEnabled,
                  initialWeights: isBiasEnabled ? _savedWeights : {},
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: primary.withOpacity(0.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                selectedMode == 'random'
                    ? AppLocale.get(currentLang, 'start_random')
                    : selectedMode == 'weak_areas'
                    ? AppLocale.get(currentLang, 'start_weak')
                    : AppLocale.get(currentLang, 'start_linear'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}