/// Build version tracking and naming convention.
///
/// Naming Convention:
/// - Semantic Version: major.minor.patch-beta.N+buildNumber
/// - Build Codename: Fruit names (rotates through 46 fruits for excellent variety)
/// - Display format: "v1.0.0-beta.3 (Mango) · Build #3"
///
/// This helps identify issues in the field and track which exact build
/// a user or tester is running.
// ignore: unnecessary_library_name
library version;

class AppVersion {
  // ── Semantic versioning ────────────────────────────────────────────────
  /// Major version: breaking changes
  static const int major = 1;

  /// Minor version: new features/improvements
  static const int minor = 0;

  /// Patch version: bug fixes
  static const int patch = 0;

  /// Pre-release identifier (e.g., beta.0)
  static const String preRelease = 'beta.0';

  /// Build number incremented on each release
  static const int buildNumber = 0;

  /// All available build codenames (Fruit names, alphabetically ordered)
  /// Cycles through on each build for easy verbal identification
  /// 46 fruits provide excellent variety across builds
  static const List<String> buildCodenames = [
    'Apple',
    'Apricot',
    'Avocado',
    'Banana',
    'Blackberry',
    'Blueberry',
    'Boysenberry',
    'Cantaloupe',
    'Cherry',
    'Coconut',
    'Cranberry',
    'Damson',
    'Date',
    'Dragonfruit',
    'Elderberry',
    'Fig',
    'Grapefruit',
    'Grape',
    'Guava',
    'Honeydew',
    'Kiwi',
    'Lemon',
    'Lime',
    'Lychee',
    'Mango',
    'Melon',
    'Mulberry',
    'Nectarine',
    'Orange',
    'Papaya',
    'Passion Fruit',
    'Peach',
    'Pear',
    'Persimmon',
    'Pineapple',
    'Plum',
    'Pomegranate',
    'Quince',
    'Rambutan',
    'Raspberry',
    'Soursop',
    'Strawberry',
    'Tamarind',
    'Tangerine',
    'Watermelon',
    'Yuzu',
  ];

  /// Current build codename based on buildNumber
  static String get currentCodename =>
      buildCodenames[buildNumber % buildCodenames.length];

  /// Full semantic version string (e.g., "1.0.0-beta.3")
  static String get semanticVersion => '$major.$minor.$patch-$preRelease';

  /// Full version with build number (e.g., "1.0.0-beta.3+3")
  static String get fullVersion => '$semanticVersion+$buildNumber';

  /// Human-readable version display (e.g., "v1.0.0-beta.3 (Mumbai) · Build #3")
  static String get displayVersion =>
      'v$semanticVersion ($currentCodename) · Build #$buildNumber';

  /// Short version for tooltips/badges (e.g., "1.0.0-β3")
  static String get shortVersion =>
      '$major.$minor.$patch-β$preRelease'.split('-').last;

  /// Compact display without build number (e.g., "v1.0.0-beta.3 Mumbai")
  static String get compactVersion => 'v$semanticVersion $currentCodename';
}
