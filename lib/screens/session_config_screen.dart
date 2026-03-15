import 'package:flutter/material.dart';
import 'package:mental_ability_app/config/localization.dart';

import 'quiz_screen.dart'; // Ensure this file exists

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

                    const SizedBox(height: 16),

                    // TOPIC GRID
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
                            title: 'Figure Series',
                            icon: Icons.trending_flat,
                            color: accentPurple),
                        _buildTopicCard(id: 'analogy',
                            title: AppLocale.get(currentLang, 'analogy'),
                            icon: Icons.compare_arrows,
                            color: const Color(0xFF14B8A6)),

                        // GEO COMPLETION - DISABLED AS TODO
                        // _buildTopicCard(id: 'geo_completion', title: 'Geo Completion',                         icon: Icons.change_history,          color: const Color(0xFFF59E0B)),

                        _buildTopicCard(id: 'mirror_shape',
                            title: 'Mirror Shape',
                            icon: Icons.flip,
                            color: const Color(0xFFF43F5E)),
                        _buildTopicCard(id: 'mirror_text',
                            title: 'Mirror Text/Clock',
                            icon: Icons.text_fields,
                            color: accentOrange),
                        _buildTopicCard(id: 'punch_hole',
                            title: 'Punch Hole',
                            icon: Icons.radio_button_unchecked,
                            color: accentEmerald),

                        // EMBEDDED FIGURE - DISABLED AS TODO
                        // _buildTopicCard(id: 'embedded',       title: 'Embedded Figure',                        icon: Icons.center_focus_strong,     color: const Color(0xFF14B8A6)),
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
              GestureDetector(
                onTap: () => setState(
                      () => currentLang = currentLang == 'EN' ? 'MR' : 'EN',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.translate, color: primary, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        currentLang,
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
          const SizedBox(height: 20),

          // Setting 1: Total Questions
          _buildSettingRow(
            icon: Icons.format_list_numbered,
            label: AppLocale.get(currentLang, 'total_questions'),
            children: [10, 20, 50]
                .map(
                  (val) => _buildChip(
                    label: val.toString(),
                    isSelected: selectedCount == val,
                    onTap: () => setState(() => selectedCount = val),
                  ),
            )
                .toList(),
          ),
          const SizedBox(height: 16),

          // Setting 2: Time Per Question
          _buildSettingRow(
            icon: Icons.timer_outlined,
            label: AppLocale.get(currentLang, 'time_per_question'),
            children: ['30s', '2m', 'Unlimited']
                .map(
                  (val) => _buildChip(
                    label: val,
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => QuizScreen(
                  mode: selectedMode,
                  totalQuestions: selectedCount,
                  timePerQuestion: selectedTime,
                  biasEnabled: isBiasEnabled, // ← wired to the toggle
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
