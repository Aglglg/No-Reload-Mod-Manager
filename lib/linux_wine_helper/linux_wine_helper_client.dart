import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

class IniCheckError {
  final int lineIndex;
  final String filePath;
  final String trimmedLine;
  final String reason;

  IniCheckError({
    required this.lineIndex,
    required this.filePath,
    required this.trimmedLine,
    required this.reason,
  });
}

class WineHelperClient {
  static const int port = 38271;

  Socket? _socket;
  final Queue<Completer<String>> _waitingForReply = Queue();

  Future<void> connect() async {
    final socket = await Socket.connect('127.0.0.1', port);
    socket.setOption(SocketOption.tcpNoDelay, true);
    _socket = socket;

    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (replyLine) {
            if (_waitingForReply.isNotEmpty) {
              _waitingForReply.removeFirst().complete(replyLine);
            }
          },
          onDone: _failAllWaiting,
          onError: (_) => _failAllWaiting(),
        );
  }

  void _failAllWaiting() {
    _socket = null;
    while (_waitingForReply.isNotEmpty) {
      _waitingForReply.removeFirst().completeError('Wine helper disconnected');
    }
  }

  Future<String> _send(String command) {
    final socket = _socket;
    if (socket == null) return Future.error('Wine helper not connected');

    final reply = Completer<String>();
    _waitingForReply.add(reply);
    socket.write('$command\n');
    return reply.future;
  }

  Future<void> simulateKeyDown(int key) async => await _send('keydown $key');
  Future<void> simulateKeyUp(int key) async => await _send('keyup $key');
  Future<void> setCursorPos(int x, int y) async =>
      await _send('setcursor $x $y');

  Future<List<IniCheckError>> checkIni({
    required String iniPath,
    required String basePath,
    required List<String> knownLibNamespaces,
  }) async {
    final command = [
      'inicheck',
      iniPath,
      basePath,
      ...knownLibNamespaces,
    ].join('\t');
    final reply = jsonDecode(await _send(command)) as Map<String, dynamic>;

    // Throw instead of returning an empty list, so "failed" never looks like "no errors"
    if (reply['error'] != null) {
      throw Exception('Ini check failed: ${reply['error']}');
    }

    return (reply['errors'] as List)
        .map(
          (item) => IniCheckError(
            lineIndex: item['line'],
            filePath: item['file'],
            trimmedLine: item['text'],
            reason: item['reason'],
          ),
        )
        .toList();
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}
