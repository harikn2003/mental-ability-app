// Phone preview over Wi-Fi: open the app in the phone's browser by scanning a
// QR code - no install, no USB/wireless debugging, developer options can stay
// off (banking apps refuse to run with them on).
//
//   dart run tool/phone_preview.dart            build the web release and serve it
//   dart run tool/phone_preview.dart --no-build serve the last build as-is
//   dart run tool/phone_preview.dart --qr-only 8080
//                                               just print the QR for a port (used
//                                               before `flutter run -d web-server`,
//                                               the live-reload run configuration)
//   add --light for a light-background console (the QR is drawn inverted by
//   default, for dark consoles like Android Studio's).
//
// The phone and this PC must be on the same Wi-Fi. The first time, Windows
// Firewall asks whether to allow Dart on private networks: allow it.
//
// Progress saved in the browser (Hive -> IndexedDB) is separate from the
// installed app's.
//
// Run configurations for Android Studio: .run/ (see docs/phone_preview.md).

import 'dart:io';

import 'package:qr/qr.dart';

const previewPort = 8081;

Future<void> main(List<String> args) async {
  final light = args.contains('--light');
  if (args.contains('--qr-only')) {
    final port = int.tryParse(args.lastWhere((a) => int.tryParse(a) != null, orElse: () => '8080')) ?? 8080;
    await _announce(port, light, live: true);
    return;
  }

  if (!args.contains('--no-build')) {
    stdout.writeln('Building the web release (about a minute)...');
    final flutter = Platform.isWindows ? 'flutter.bat' : 'flutter';
    final build = await Process.start(flutter, ['build', 'web', '--release'], mode: ProcessStartMode.inheritStdio, runInShell: true);
    if (await build.exitCode != 0) {
      stderr.writeln('Build failed - see above.');
      exit(1);
    }
  }

  final root = Directory('build/web');
  if (!File('${root.path}/index.html').existsSync()) {
    stderr.writeln('No web build in build/web - run without --no-build first.');
    exit(1);
  }

  final HttpServer server;
  try {
    server = await HttpServer.bind(InternetAddress.anyIPv4, previewPort);
  } on SocketException {
    stderr.writeln('Port $previewPort is busy - is another preview still running? Stop it first.');
    exit(1);
  }
  await _announce(previewPort, light, live: false);
  stdout.writeln('Serving build/web. Stop with the red Stop button (or Ctrl+C).');

  await for (final req in server) {
    _serve(req, root);
  }
}

/// Serves a file from the web build; unknown paths get index.html (the app
/// handles its own routes). No caching, so a refresh always shows the latest
/// build.
Future<void> _serve(HttpRequest req, Directory root) async {
  final res = req.response;
  try {
    var path = Uri.decodeComponent(req.uri.path);
    if (path.contains('..')) {
      res.statusCode = HttpStatus.forbidden;
      return;
    }
    if (path == '/' || path.isEmpty) path = '/index.html';
    var file = File('${root.path}$path');
    if (!file.existsSync()) file = File('${root.path}/index.html');
    res.headers
      ..contentType = _mime(file.path)
      ..set(HttpHeaders.cacheControlHeader, 'no-store');
    await res.addStream(file.openRead());
  } catch (_) {
    res.statusCode = HttpStatus.internalServerError;
  } finally {
    await res.close();
  }
}

ContentType _mime(String path) {
  final ext = path.split('.').last.toLowerCase();
  return switch (ext) {
    'html' => ContentType.html,
    'js' || 'mjs' => ContentType('application', 'javascript', charset: 'utf-8'),
    'json' => ContentType.json,
    'css' => ContentType('text', 'css', charset: 'utf-8'),
    'wasm' => ContentType('application', 'wasm'),
    'png' => ContentType('image', 'png'),
    'jpg' || 'jpeg' => ContentType('image', 'jpeg'),
    'svg' => ContentType('image', 'svg+xml'),
    'ico' => ContentType('image', 'x-icon'),
    'otf' => ContentType('font', 'otf'),
    'ttf' => ContentType('font', 'ttf'),
    'woff2' => ContentType('font', 'woff2'),
    _ => ContentType.binary,
  };
}

/// This PC's address on the local network: prefers home-network ranges and
/// real adapters over virtual ones (WSL / Hyper-V / VPN).
Future<List<String>> _lanAddresses() async {
  final found = <(int, String)>[];
  for (final nic in await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false)) {
    final name = nic.name.toLowerCase();
    final virtual = ['vethernet', 'wsl', 'hyper-v', 'virtualbox', 'vmware', 'docker', 'loopback', 'tailscale', 'zerotier']
        .any(name.contains);
    for (final a in nic.addresses) {
      final ip = a.address;
      var score = ip.startsWith('192.168.') ? 3 : ip.startsWith('10.') ? 2 : ip.startsWith('172.') ? 1 : 0;
      if (name.contains('wi-fi') || name.contains('wlan') || name.contains('wireless')) score += 2;
      if (virtual) score -= 5;
      found.add((score, ip));
    }
  }
  found.sort((a, b) => b.$1 - a.$1);
  return [for (final f in found) f.$2];
}

Future<void> _announce(int port, bool light, {required bool live}) async {
  final ips = await _lanAddresses();
  if (ips.isEmpty) {
    stderr.writeln('No network address found - is this PC on Wi-Fi?');
    return;
  }
  final url = 'http://${ips.first}:$port';
  stdout
    ..writeln()
    ..writeln(live
        ? 'Live preview (debug build, hot restart updates the phone) will be at:'
        : 'Phone preview is ready:')
    ..writeln('  $url')
    ..writeln()
    ..write(_qrText(url, light))
    ..writeln('Scan with the phone camera (same Wi-Fi as this PC).');
  if (ips.length > 1) stdout.writeln('Not loading? Try: ${ips.skip(1).map((i) => 'http://$i:$port').join('  ')}');
  stdout.writeln();
}

/// QR code as text, two modules per character using half blocks, with the
/// quiet zone scanners need.
String _qrText(String data, bool light) {
  final qr = QrImage(QrCode(payload: QrPayload.fromString(data), errorCorrectLevel: QrErrorCorrectLevel.medium));
  final n = qr.moduleCount;
  const quiet = 2;
  // Dark console: draw the light modules as blocks, so the code shows as
  // dark-on-light like a printed one.
  bool dark(int x, int y) => x >= 0 && y >= 0 && x < n && y < n && qr.isDark(y, x);
  bool ink(int x, int y) => light ? dark(x, y) : !dark(x, y);
  final b = StringBuffer();
  for (int y = -quiet; y < n + quiet; y += 2) {
    b.write('  ');
    for (int x = -quiet; x < n + quiet; x++) {
      final top = ink(x, y), bottom = ink(x, y + 1);
      b.write(top && bottom
          ? '█'
          : top
              ? '▀'
              : bottom
                  ? '▄'
                  : ' ');
    }
    b.writeln();
  }
  return b.toString();
}
