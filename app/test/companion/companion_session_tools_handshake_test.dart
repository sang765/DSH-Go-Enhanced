// Split out of companion_session_tools_test.dart: declaring a testWidgets
// installs TestWidgetsFlutterBinding for the whole suite, whose fake
// HttpClient would turn that file's real-HttpServer tests into HTTP 400.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dsh_app/companion/companion_session_tools.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';

class _ConflictBody extends DshConnection {
  _ConflictBody() : super(Uri.parse('http://127.0.0.1'));
  final body = StreamController<Uint8List>();
  late DshHttpAbort request;

  @override
  Future<DshHttpStreamResponse> postJsonStream(
    String path, Object? payload, {
    required DshHttpAbort abort, Duration? headerTimeout, Duration? idleTimeout = const Duration(seconds: 20),
  }) async {
    request = abort;
    return DshHttpStreamResponse(HttpStatus.conflict, 'application/json', body.stream, () async {});
  }
}

void main() {
  testWidgets('a partial conflict reply releases the phone handshake on its original deadline', (tester) async {
    final connection = _ConflictBody();
    final client = DshClient(connection);
    Object? failure;
    final pending = CompanionSessionTools.open(
      client, sessionId: 'cabin', requestId: 'turn', isCurrent: () => true,
      tools: [companionNotifyTool(deliver: (_, _) => throw StateError('no call was offered'))],
    ).then<void>((_) {}, onError: (Object error) { failure = error; });
    addTearDown(() async {
      await connection.body.close();
      await client.close();
    });
    await tester.pump();
    expect(connection.body.hasListener, isTrue);
    await tester.pump(const Duration(seconds: 7));
    connection.body.add(Uint8List.fromList(utf8.encode('{"error":')));
    await tester.pump();
    expect(connection.request.isAborted, isFalse);
    expect(failure, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(failure, isA<TimeoutException>());
    expect(connection.request.isAborted, isTrue);
    await pending;
  });
}
