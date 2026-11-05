// The release command (tool/release.dart): works out the next beta, checks a
// typed tag, and rewrites pubspec.yaml and version.dart together so they
// can't drift apart. The codename it announces must be the one the app shows.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mental_ability_app/config/version.dart';

import '../tool/release_version.dart';

const _pubspec = 'name: x\n# version: 9.9.9\nversion: 1.0.0-beta.9+9\n\nenvironment:\n  sdk: ^3.8.1\n';

void main() {
  final versionDart = File('lib/config/version.dart').readAsStringSync();

  test('reads the version from pubspec.yaml', () {
    final v = ReleaseVersion.fromPubspec(_pubspec)!;
    expect((v.major, v.minor, v.patch, v.beta, v.build), (1, 0, 0, 9, 9));
    expect(v.tag, 'v1.0.0-beta.9');
    expect(v.pubspecVersion, '1.0.0-beta.9+9');
  });

  test('next beta: one up from a released version, the same one if it was never tagged', () {
    final v = ReleaseVersion.fromPubspec(_pubspec)!;
    expect(v.next(currentTagged: true).pubspecVersion, '1.0.0-beta.10+10');
    expect(v.next(currentTagged: false).pubspecVersion, '1.0.0-beta.9+9');
  });

  test('a typed tag must be vX.Y.Z-beta.N; the build number follows on', () {
    expect(ReleaseVersion.fromTag('v1.0.0-beta.12', build: 10)!.pubspecVersion, '1.0.0-beta.12+10');
    expect(ReleaseVersion.fromTag('v1.1.0-beta.1', build: 10)!.minor, 1);
    for (final bad in ['1.0.0-beta.10', 'v1.0-beta.1', 'v1.0.0-rc.1', 'v1.0.0-beta.', 'v1.0.0-beta.10 ']) {
      expect(ReleaseVersion.fromTag(bad, build: 10), isNull, reason: bad);
    }
  });

  test('pubspec.yaml: only the version line changes', () {
    final v = ReleaseVersion.fromTag('v1.0.0-beta.10', build: 10)!;
    final out = v.applyToPubspec(_pubspec);
    expect(out, _pubspec.replaceFirst('version: 1.0.0-beta.9+9', 'version: 1.0.0-beta.10+10'));
  });

  test('version.dart: beta, build and major/minor/patch all follow the tag', () {
    final v = ReleaseVersion.fromTag('v1.2.3-beta.10', build: 12)!;
    final out = v.applyToVersionDart(versionDart);
    expect(out, contains("static const String preRelease = 'beta.10';"));
    expect(out, contains('static const int buildNumber = 12;'));
    expect(out, contains('static const int major = 1;'));
    expect(out, contains('static const int minor = 2;'));
    expect(out, contains('static const int patch = 3;'));
    // Nothing else moves.
    expect(out.length - versionDart.length, lessThan(8));
    expect(ReleaseVersion.fromVersionDart(out)!.pubspecVersion, '1.2.3-beta.10+12');
  });

  test('the codename is the one the app shows for that build', () {
    final names = codenamesIn(versionDart);
    expect(names, AppVersion.buildCodenames);
    expect(codenameFor(AppVersion.buildNumber, names), AppVersion.currentCodename);
    expect(codenameFor(AppVersion.buildNumber + 1, names), AppVersion.buildCodenames[(AppVersion.buildNumber + 1) % names.length]);
  });

  test('the two version files in the repository agree', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(ReleaseVersion.fromVersionDart(versionDart)!.pubspecVersion, ReleaseVersion.fromPubspec(pubspec)!.pubspecVersion);
  });
}
