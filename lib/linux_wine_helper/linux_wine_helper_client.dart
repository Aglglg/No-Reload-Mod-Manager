import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

class WineHelperClient {
  static const int port = 38271;

  Socket? _socket;
  final Queue<Completer<void>> _waitingForDone = Queue();

  Future<void> connect() async {
    final socket = await Socket.connect('127.0.0.1', port);
    socket.setOption(SocketOption.tcpNoDelay, true);
    _socket = socket;

    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen(
          (text) {
            for (final _ in '\n'.allMatches(text)) {
              if (_waitingForDone.isNotEmpty) {
                _waitingForDone.removeFirst().complete();
              }
            }
          },
          onDone: _failAllWaiting,
          onError: (_) => _failAllWaiting(),
        );
  }

  void _failAllWaiting() {
    _socket = null;
    while (_waitingForDone.isNotEmpty) {
      _waitingForDone.removeFirst().completeError('Wine helper disconnected');
    }
  }

  Future<void> _send(String command) {
    final socket = _socket;
    if (socket == null) return Future.error('Wine helper not connected');

    final finished = Completer<void>();
    _waitingForDone.add(finished);
    socket.write('$command\n');
    return finished.future;
  }

  Future<void> simulateKeyDown(int key) => _send('keydown $key');
  Future<void> simulateKeyUp(int key) => _send('keyup $key');
  Future<void> setCursorPos(int x, int y) => _send('setcursor $x $y');

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }
}
