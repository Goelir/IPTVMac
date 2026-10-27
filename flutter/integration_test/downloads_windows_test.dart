import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:iptvmac/downloads/background_download_engine.dart';
import 'package:iptvmac/downloads/download_engine.dart';

/// Runs the real app shell on a real machine (CI: `flutter test integration_test -d windows`): the download engine saves a file from a
/// local server to a folder, reports it done, and the file is complete.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the download engine saves a file from a local server and reports it done', (t) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final data = List<int>.generate(3 * 1024 * 1024, (i) => i % 251);
    server.listen((r) {
      r.response.headers.contentLength = data.length;
      r.response.add(data);
      r.response.close();
    });
    final dir = Directory.systemTemp.createTempSync('iptvmac-downloads');
    addTearDown(() => dir.deleteSync(recursive: true));
    final sep = Platform.pathSeparator;
    final engine = BackgroundDownloadEngine(partialDir: '${dir.path}$sep.partial');
    final finished = Completer<EngineUpdate>();
    engine.updates.listen((u) {
      if ((u.state == EngineState.done || u.state == EngineState.failed) && !finished.isCompleted) finished.complete(u);
    });
    await engine.start();
    final path = '${dir.path}$sep${'Test movie.mp4'}';
    final accepted = await engine.enqueue(EngineJob(id: 'it1', url: Uri.parse('http://127.0.0.1:${server.port}/movie.mp4'), path: path, title: 'Test movie'));
    expect(accepted, isTrue);
    final u = await finished.future.timeout(const Duration(seconds: 90));
    expect(u.state, EngineState.done, reason: 'error: ${u.error}');
    expect(File(path).existsSync(), isTrue);
    expect(File(path).lengthSync(), data.length);
  });
}
