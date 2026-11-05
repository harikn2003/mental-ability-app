// Version arithmetic for tool/release.dart: plain text in, plain text out,
// so it can be tested without git (test/release_tool_test.dart).

/// A beta version: `major.minor.patch-beta.N+build`.
class ReleaseVersion {
  final int major, minor, patch, beta, build;
  const ReleaseVersion(this.major, this.minor, this.patch, this.beta, this.build);

  String get name => '$major.$minor.$patch-beta.$beta';
  String get tag => 'v$name';
  String get pubspecVersion => '$name+$build';

  static final _pubspecLine = RegExp(r'^version:[ \t]*(\d+)\.(\d+)\.(\d+)-beta\.(\d+)\+(\d+)[ \t]*(?=\r?$)', multiLine: true);
  static final _tag = RegExp(r'^v(\d+)\.(\d+)\.(\d+)-beta\.(\d+)$');

  static ReleaseVersion? fromPubspec(String text) {
    final m = _pubspecLine.firstMatch(text);
    if (m == null) return null;
    final n = [for (int i = 1; i <= 5; i++) int.parse(m.group(i)!)];
    return ReleaseVersion(n[0], n[1], n[2], n[3], n[4]);
  }

  static int? _const(String text, String name) =>
      int.tryParse(RegExp('static const int $name = (\\d+);').firstMatch(text)?.group(1) ?? '');

  static ReleaseVersion? fromVersionDart(String text) {
    final beta = int.tryParse(RegExp(r"static const String preRelease = 'beta\.(\d+)';").firstMatch(text)?.group(1) ?? '');
    final parts = [_const(text, 'major'), _const(text, 'minor'), _const(text, 'patch'), beta, _const(text, 'buildNumber')];
    if (parts.contains(null)) return null;
    return ReleaseVersion(parts[0]!, parts[1]!, parts[2]!, parts[3]!, parts[4]!);
  }

  /// A tag typed by hand (`vX.Y.Z-beta.N`) with the given build number, or
  /// null if it isn't in that form.
  static ReleaseVersion? fromTag(String tag, {required int build}) {
    final m = _tag.firstMatch(tag);
    if (m == null) return null;
    return ReleaseVersion(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3)!), int.parse(m.group(4)!), build);
  }

  /// The version to release next: one beta and one build up from a
  /// released version, or this one if it was bumped but never tagged.
  ReleaseVersion next({required bool currentTagged}) =>
      currentTagged ? ReleaseVersion(major, minor, patch, beta + 1, build + 1) : this;

  String applyToPubspec(String text) => text.replaceFirst(_pubspecLine, 'version: $pubspecVersion');

  String applyToVersionDart(String text) => text
      .replaceFirst(RegExp(r'static const int major = \d+;'), 'static const int major = $major;')
      .replaceFirst(RegExp(r'static const int minor = \d+;'), 'static const int minor = $minor;')
      .replaceFirst(RegExp(r'static const int patch = \d+;'), 'static const int patch = $patch;')
      .replaceFirst(RegExp(r"static const String preRelease = '[^']*';"), "static const String preRelease = 'beta.$beta';")
      .replaceFirst(RegExp(r'static const int buildNumber = \d+;'), 'static const int buildNumber = $build;');

  @override
  String toString() => pubspecVersion;
}

/// The codename list in `lib/config/version.dart` (`buildCodenames`).
List<String> codenamesIn(String versionDart) {
  final start = versionDart.indexOf('buildCodenames = [');
  if (start < 0) return const [];
  final end = versionDart.indexOf('];', start);
  final body = versionDart.substring(start, end).replaceAll(RegExp(r'//[^\n]*'), ''); // skip commented-out names
  return [for (final m in RegExp(r"'([^']+)'").allMatches(body)) m.group(1)!];
}

/// The codename the app shows for [build] (same rule as `AppVersion.currentCodename`).
String codenameFor(int build, List<String> names) => names.isEmpty ? '' : names[build % names.length];
