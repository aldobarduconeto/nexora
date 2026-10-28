import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:nexora/src/utils/serial_task_queue.dart';

import 'package:file_picker/file_picker.dart';

/// Negotiated bounded batches keep memory and channel queues bounded.
class FileTransferService {
  FileTransferService({
    required this.send,
    required this.notice,
    Future<String?> Function(String name)? chooseDirectory,
    this.partTimeout = const Duration(seconds: 30),
  }) : _chooseDirectory =
           chooseDirectory ??
           ((name) => FilePicker.getDirectoryPath(
             dialogTitle: 'Receber $name - escolha a pasta',
           ));
  final Future<String?> Function(String name) _chooseDirectory;
  final Duration partTimeout;
  static const chunkSize = 12 * 1024;
  static const maxWindow = 8;
  final _receiving = SerialTaskQueue();
  final Map<int, Completer<bool>> _pending = {};
  int _window = 1;
  int _generation = 0;
  Completer<void> _abortSignal = Completer<void>();
  int _queued = 0;
  bool _picking = false;
  final Future<void> Function(String) send;
  final void Function(String) notice;
  static const prefix = 'NEXORA_FILE_V1:';
  String? _outgoing;
  int _sequence = 0;
  String? _incoming;
  RandomAccessFile? _output;
  File? _partial;
  int _expected = 0;
  int _received = 0;
  int _next = 0;
  bool _closed = false;
  Timer? _idle;

  Future<void> _frame(Map<String, dynamic> frame) =>
      send('$prefix${jsonEncode(frame)}');

  Future<void> _sendPart(
    Map<String, dynamic> frame, {
    bool selecting = false,
  }) async {
    if (_closed || _outgoing == null)
      throw StateError('Transferencia encerrada.');
    final sequence = _sequence++;
    final ack = Completer<bool>();
    _pending[sequence] = ack;
    frame.addAll({'id': _outgoing, 'seq': sequence});
    try {
      await _frame(frame);
      final accepted = await ack.future.timeout(
        selecting ? const Duration(minutes: 5) : partTimeout,
      );
      if (!accepted)
        throw StateError('Transferencia recusada ou interrompida.');
    } finally {
      _pending.remove(sequence);
    }
  }

  Future<void> pickAndSend() async {
    if (_picking || _outgoing != null || _closed) return;
    _picking = true;
    final generation = _generation;
    try {
      final selected = await FilePicker.pickFile(type: FileType.any);
      if (selected == null || _closed || generation != _generation) return;
      final size = await selected.length();
      if (size == null)
        throw StateError('Nao foi possivel obter o tamanho do arquivo.');
      if (_closed || generation != _generation) return;
      await sendFile(
        name: selected.name,
        size: size,
        bytes: selected.readAsByteStream(),
      );
    } finally {
      _picking = false;
    }
  }

  /// Streams the source without collecting the complete file in memory.
  Future<void> sendFile({
    required String name,
    required int size,
    required Stream<List<int>> bytes,
  }) async {
    if (_closed || _outgoing != null)
      throw StateError('Transferencia indisponivel.');
    if (size < 0) throw ArgumentError.value(size);
    _outgoing =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final generation = _generation;
    _sequence = 0;
    _window = 1;
    try {
      await _sendPart({
        'op': 'start',
        'name': name,
        'size': size,
      }, selecting: true);
      Object? failure;
      var sent = 0;
      var batch = <Future<void>>[];
      // readAsByteStream normally emits small blocks; reblock short reads so
      // they do not create thousands of tiny packets on the channel.
      final buffer = Uint8List(chunkSize);
      var used = 0;
      Future<void> enqueue(List<int> chunk) async {
        if (_closed || generation != _generation)
          throw StateError('Transferencia interrompida.');
        sent += chunk.length;
        if (sent > size) throw StateError('O arquivo mudou durante o envio.');
        // Attach error handling immediately, including while the source waits.
        batch.add(
          _sendPart({'op': 'chunk', 'data': base64Encode(chunk)}).then(
            (_) {},
            onError: (Object error, StackTrace stack) {
              failure ??= error;
            },
          ),
        );
        if (batch.length >= _window) {
          await Future.wait(batch);
          batch = [];
          if (failure != null) throw failure!;
        }
      }

      await for (final block in bytes) {
        var offset = 0;
        while (offset < block.length) {
          final count = min(chunkSize - used, block.length - offset);
          buffer.setRange(used, used + count, block, offset);
          used += count;
          offset += count;
          if (used == chunkSize) {
            await enqueue(buffer);
            used = 0;
          }
        }
      }
      if (used > 0) await enqueue(Uint8List.sublistView(buffer, 0, used));
      await Future.wait(batch);
      if (failure != null) throw failure!;
      if (sent != size) throw StateError('O arquivo mudou durante o envio.');
      await _sendPart({'op': 'end'});
      notice('Arquivo enviado: $name');
    } catch (_) {
      if (!_closed && generation == _generation) {
        try {
          await _frame({'op': 'cancel', 'id': _outgoing});
        } catch (_) {}
      }
      rethrow;
    } finally {
      for (final ack in _pending.values) {
        if (!ack.isCompleted) ack.complete(false);
      }
      _pending.clear();
      _outgoing = null;
    }
  }

  Future<void> receive(String text) async {
    if (_closed || !text.startsWith(prefix)) return;
    Map<String, dynamic> frame;
    try {
      frame = jsonDecode(text.substring(prefix.length)) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    if (frame['op'] == 'ack') {
      final ack = frame['id'] == _outgoing ? _pending[frame['seq']] : null;
      if (ack != null && !ack.isCompleted) {
        if (frame['seq'] == 0 && frame['window'] == maxWindow)
          _window = maxWindow;
        ack.complete(frame['ok'] == true);
      }
      return;
    }
    if (_queued >= maxWindow + 2) {
      try {
        await _frame({
          'op': 'ack',
          'id': frame['id'],
          'seq': frame['seq'],
          'ok': false,
        });
      } catch (_) {}
      return;
    }
    _queued++;
    final generation = _generation;
    try {
      await _receiving.run(() async {
        if (!_closed && generation == _generation)
          await _receiveFrame(frame, generation);
      });
    } finally {
      _queued--;
    }
  }

  Future<void> _receiveFrame(Map<String, dynamic> frame, int generation) async {
    try {
      final id = frame['id'];
      final seq = frame['seq'];
      final op = frame['op'];
      if (op == 'cancel') {
        if (id == _incoming) await _discard();
        return;
      }
      if (op == 'start') {
        if (_incoming != null ||
            id is! String ||
            id.length > 80 ||
            !RegExp(r'^[0-9]+-[0-9]+$').hasMatch(id) ||
            seq != 0 ||
            frame['size'] is! int ||
            (frame['size'] as int) < 0) {
          await _frame({'op': 'ack', 'id': id, 'seq': seq, 'ok': false});
          return;
        }
        _incoming = id;
        final name = (frame['name'] as String)
            .substring(0, min((frame['name'] as String).length, 120))
            .split(RegExp(r'[/\\]'))
            .last
            .replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_');
        final directory = await Future.any<String?>([
          _chooseDirectory(name),
          _abortSignal.future.then<String?>((_) => null),
        ]);
        if (directory == null || _closed || generation != _generation) {
          await _discard();
          if (!_closed)
            await _frame({'op': 'ack', 'id': id, 'seq': seq, 'ok': false});
          return;
        }
        // Exclusive creation avoids replacing an existing user file.
        final destination = File(
          '$directory${Platform.pathSeparator}nexora-$id-$name',
        );
        await destination.create(exclusive: true);
        _partial = destination;
        _output = await _partial!.open(mode: FileMode.writeOnly);
        _expected = frame['size'] as int;
        _received = 0;
        _next = 1;
        notice('Recebendo arquivo: $name');
      } else {
        if (id != _incoming || seq != _next || _output == null) {
          await _frame({'op': 'ack', 'id': id, 'seq': seq, 'ok': false});
          return;
        }
        if (op == 'chunk') {
          final bytes = base64Decode(frame['data'] as String);
          if (bytes.length > chunkSize || _received + bytes.length > _expected)
            throw const FormatException('Parte inválida.');
          await _output!.writeFrom(bytes);
          _received += bytes.length;
        } else if (op == 'end') {
          if (_received != _expected)
            throw const FormatException('Arquivo incompleto.');
          await _output!.flush();
          await _output!.close();
          _output = null;
          notice('Arquivo recebido: ${_partial!.path}');
          _partial = null;
          _incoming = null;
        } else {
          throw const FormatException('Operação inválida.');
        }
        _next++;
      }
      _idle?.cancel();
      if (_incoming != null)
        _idle = Timer(
          const Duration(minutes: 5),
          () => unawaited(_receiving.run(_discard)),
        );
      await _frame({
        'op': 'ack',
        'id': id,
        'seq': seq,
        'ok': true,
        'window': maxWindow,
      });
    } catch (_) {
      await _discard();
      notice('Não foi possível receber o arquivo.');
      if (!_closed) {
        try {
          await _frame({
            'op': 'ack',
            'id': frame['id'],
            'seq': frame['seq'],
            'ok': false,
          });
        } catch (_) {}
      }
    }
  }

  Future<void> _discard() async {
    _idle?.cancel();
    final output = _output;
    final partial = _partial;
    _output = null;
    _partial = null;
    _incoming = null;
    try {
      try {
        await output?.close();
      } finally {
        if (partial != null && await partial.exists()) await partial.delete();
      }
    } catch (_) {
      notice(
        'Nao foi possivel remover o arquivo parcial. Confira a pasta escolhida.',
      );
    }
  }

  Future<void> abort() async {
    _generation++;
    _abortSignal.complete();
    _abortSignal = Completer<void>();
    for (final ack in _pending.values) {
      if (!ack.isCompleted) ack.complete(false);
    }
    await _receiving.run(_discard);
  }

  Future<void> close() async {
    _closed = true;
    await abort();
  }
}
