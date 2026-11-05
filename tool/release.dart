// Cuts a beta release from master, in one go:
//
//   dart run tool/release.dart                  asks for the tag (Enter = the next beta)
//   dart run tool/release.dart --tag v1.0.0-beta.12
//   dart run tool/release.dart --dry-run        shows what it would do, changes nothing
//   dart run tool/release.dart --skip-tests     skips flutter analyze/test (CI still runs them)
//   dart run tool/release.dart --yes            no questions: the --tag given, or the next beta
//   dart run tool/release.dart --print-codename prints the current build's codename (used by CI)
//
// Steps: checks you're on an up-to-date, clean master; asks for the tag;
// shows the version, build number, codename and the commits going out;
// runs flutter analyze and flutter test; bumps pubspec.yaml and
// lib/config/version.dart together; commits; tags; and pushes master and
// the tag in one atomic push. The tag push starts the GitHub Actions build.
// Replaces the old pre-push hook. Works the same on Windows and Linux.

import 'dart:io';

import 'release_version.dart';

final root = File.fromUri(Platform.script).parent.parent.path;
final pubspecFile = File('$root/pubspec.yaml');
final versionFile = File('$root/lib/config/version.dart');

Never fail(String message) {
  stderr.writeln('\n✗ $message');
  exit(1);
}

String git(List<String> args, {bool allowFail = false}) {
  final r = Process.runSync('git', args, workingDirectory: root);
  if (r.exitCode != 0 && !allowFail) fail('git ${args.join(' ')} failed:\n${r.stderr}');
  return (r.stdout as String).trim();
}

bool tagExists(String tag) =>
    git(['rev-parse', '-q', '--verify', 'refs/tags/$tag'], allowFail: true).isNotEmpty ||
    git(['ls-remote', '--tags', 'origin', 'refs/tags/$tag'], allowFail: true).isNotEmpty;

String ask(String question, String fallback) {
  stdout.write('$question [$fallback]: ');
  final answer = stdin.readLineSync()?.trim() ?? '';
  return answer.isEmpty ? fallback : answer;
}

Future<void> run(String what, List<String> command) async {
  stdout.writeln('\n▶ $what: ${command.join(' ')}');
  final p = await Process.start(command.first, command.skip(1).toList(),
      workingDirectory: root, mode: ProcessStartMode.inheritStdio, runInShell: Platform.isWindows);
  if (await p.exitCode != 0) fail('$what failed. Nothing was committed, tagged or pushed.');
}

Future<void> main(List<String> args) async {
  String? flagValue(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final dryRun = args.contains('--dry-run');
  final yes = args.contains('--yes');
  final skipTests = args.contains('--skip-tests');
  final names = codenamesIn(versionFile.readAsStringSync());

  final current = ReleaseVersion.fromPubspec(pubspecFile.readAsStringSync()) ??
      fail('pubspec.yaml has no "version: X.Y.Z-beta.N+B" line.');
  if (args.contains('--print-codename')) {
    stdout.write(codenameFor(current.build, names));
    return;
  }

  // 1. On master, nothing uncommitted, nothing newer on GitHub.
  final branch = git(['rev-parse', '--abbrev-ref', 'HEAD']);
  if (branch != 'master') fail('Releases are cut from master; you are on "$branch". Run: git checkout master');
  if (git(['status', '--porcelain', '--untracked-files=no']).isNotEmpty) {
    fail('You have uncommitted changes. Commit or discard them first (git status shows them).');
  }
  stdout.writeln('Checking GitHub for newer commits and tags…');
  // Not --tags: one old local tag differs from GitHub's, and tags are
  // checked on GitHub directly (tagExists) anyway.
  git(['fetch', '--quiet', 'origin', 'master']);
  final behind = int.parse(git(['rev-list', '--count', 'HEAD..origin/master']));
  if (behind > 0) fail('GitHub has $behind commit(s) on master that you don\'t. Run: git pull');

  final inApp = ReleaseVersion.fromVersionDart(versionFile.readAsStringSync());
  if (inApp?.pubspecVersion != current.pubspecVersion) {
    stdout.writeln('! pubspec.yaml says ${current.pubspecVersion} but version.dart says ${inApp ?? 'something unreadable'}; '
        'this release sets both.');
  }

  // 2. The tag: typed, given, or the next beta.
  final currentTagged = tagExists(current.tag);
  final suggested = current.next(currentTagged: currentTagged);
  final build = suggested.build;
  final given = flagValue('--tag');
  final tag = given ?? (yes ? suggested.tag : ask('Tag for this release', suggested.tag));
  final next = ReleaseVersion.fromTag(tag, build: build) ?? fail('"$tag" isn\'t a beta tag. Use the form v1.0.0-beta.12');
  if (tagExists(next.tag)) fail('${next.tag} already exists. Tags are never reused: pick the next number.');

  // 3. What goes out.
  final lastTag = git(['describe', '--tags', '--abbrev=0', '--match', 'v*-beta.*'], allowFail: true);
  final log = git(['log', '--oneline', '--no-merges', if (lastTag.isNotEmpty) '$lastTag..HEAD']);
  final commits = log.isEmpty ? <String>[] : log.split('\n');
  final codename = codenameFor(next.build, names);
  stdout
    ..writeln('\nRelease ${next.tag}  ·  build ${next.build}  ·  codename $codename')
    ..writeln('  now:  ${current.pubspecVersion} (${codenameFor(current.build, names)})${currentTagged ? '' : ' - never released'}')
    ..writeln('  ${commits.length} commit(s) since ${lastTag.isEmpty ? 'the start' : lastTag}:');
  for (final c in commits.take(15)) {
    stdout.writeln('    $c');
  }
  if (commits.length > 15) stdout.writeln('    … and ${commits.length - 15} more');
  if (dryRun) {
    stdout.writeln('\nDry run: nothing changed.');
    return;
  }
  if (!yes && !ask('\nRelease it? (y/n)', 'n').toLowerCase().startsWith('y')) fail('Cancelled. Nothing changed.');

  // 4. Same checks as CI, before anything is written.
  if (!skipTests) {
    await run('Analyze', ['flutter', 'analyze']);
    await run('Tests', ['flutter', 'test']);
  }

  // 5. Bump, commit, tag, push (master and the tag together, or neither).
  pubspecFile.writeAsStringSync(next.applyToPubspec(pubspecFile.readAsStringSync()));
  versionFile.writeAsStringSync(next.applyToVersionDart(versionFile.readAsStringSync()));
  final message = 'chore(release): beta ${next.name} ($codename)';
  git(['add', 'pubspec.yaml', 'lib/config/version.dart']);
  git(['commit', '--quiet', '-m', message]);
  git(['tag', '-a', next.tag, '-m', message]);
  stdout.writeln('\n▶ Pushing master and ${next.tag}…');
  final push = Process.runSync('git', ['push', '--atomic', 'origin', 'master', next.tag], workingDirectory: root);
  if (push.exitCode != 0) {
    fail('Push failed:\n${push.stderr}\nThe release commit and tag exist only on this computer. Fix the cause and run:\n'
        '  git push --atomic origin master ${next.tag}\nor undo them with:\n  git tag -d ${next.tag}\n  git reset --hard HEAD~1');
  }

  final repo = git(['remote', 'get-url', 'origin']).replaceFirst(RegExp(r'\.git$'), '').replaceFirst('git@github.com:', 'https://github.com/');
  stdout
    ..writeln('\n✓ Released ${next.tag} ($codename). GitHub is building it now (about 8 minutes):')
    ..writeln('  Build:   $repo/actions')
    ..writeln('  Release: $repo/releases/tag/${next.tag}');
}
