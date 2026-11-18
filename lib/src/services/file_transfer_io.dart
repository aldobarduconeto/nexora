import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:nexora/src/models/protected_content.dart';
import 'package:nexora/src/utils/serial_task_queue.dart';
import 'package:path_provider/path_provider.dart';

enum ProtectedTransferState {
  pending,
  receiving,
  completed,
  declined,
  unavailable,
}

class ProtectedTransfer {
  ProtectedTransfer._({
    required this.id,
    required this.warning,
    required this.kind,
    required this.outgoing,
    this.channel,
  });

  final String id;
  final ContentWarning warning;
  final ProtectedContentKind kind;
  final bool outgoing;
  final String? channel;
  final sentAt = DateTime.now();
  ProtectedTransferState _state = ProtectedTransferState.pending;
  String? _result;
  Directory? _cacheDirectory;

  ProtectedTransferState get state => _state;

  /// Revealed text, or the path of a completed incoming attachment.
  String? get result => _result;

  Future<void> clearCachedContent() async {
    final directory = _cacheDirectory;
    if (directory == null) return;
    _cacheDirectory = null;
    try {
      final path = _result;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
      await directory.delete();
    } on FileSystemException {
      // The operating system can also clear the temporary directory.
    }
  }
}

/// Negotiated bounded batches keep memory and channel queues bounded.
class FileTransferService {
  FileTransferService({
    required this.send,
    required this.notice,
    this.onProtectedTransfer,
    Future<String?> Function(String name)? chooseDirectory,
    Future<Directory> Function()? protectedCacheDirectory,
    this.partTimeout = const Duration(seconds: 30),
  }) : _protectedCacheDirectory =
           protectedCacheDirectory ?? getTemporaryDirectory,
       _chooseDirectory =
           chooseDirectory ??
           ((name) => FilePicker.getDirectoryPath(
             dialogTitle: 'Receber $name - escolha a pasta',
           ));

  final Future<String?> Function(String name) _chooseDirectory;
  final Future<Directory> Function() _protectedCacheDirectory;
  final void Function(ProtectedTransfer)? onProtectedTransfer;
  final Duration partTimeout;
  static const chunkSize = 32 * 1024;
  static const maxWindow = 24;
  static const _maxProtectedTextBytes = 256 * 1024;
  final _receiving = SerialTaskQueue();
  final _pending = <int, Completer<({bool ok, bool consent})>>{};
  int _window = 1;
  int _generation = 0;
  Completer<void> _abortSignal = Completer<void>();
  int _queued = 0;
  static bool _pickingGlobal = false;
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
  ProtectedTransfer? _protectedIncoming;
  Completer<bool>? _consent;
  Completer<void>? _protectedCancel;
  BytesBuilder? _protectedText;

  bool get isBusy => _outgoing != null || _closed;

  Future<void> _frame(Map<String, dynamic> frame) =>
      send('$prefix${jsonEncode(frame)}');

  Future<void> _sendPart(
    Map<String, dynamic> frame, {
    bool selecting = false,
    bool protected = false,
  }) async {
    if (_closed || _outgoing == null) {
      throw StateError('Transferência encerrada.');
    }
    final sequence = _sequence++;
    final ack = Completer<({bool ok, bool consent})>();
    _pending[sequence] = ack;
    frame.addAll({'id': _outgoing, 'seq': sequence});
    try {
      await _frame(frame);
      final accepted = await ack.future.timeout(
        selecting ? const Duration(minutes: 5) : partTimeout,
      );
      if (!accepted.ok || (protected && !accepted.consent)) {
        throw StateError('Transferência recusada ou interrompida.');
      }
    } finally {
      _pending.remove(sequence);
    }
  }

  /// Picks a single file and sends it to one or multiple P2P targets (1:1 or Group).
  static Future<bool> pickAndSendToTargets(
    List<FileTransferService> targets, {
    ContentWarning? warning,
    String? channel,
  }) async {
    final available = targets.where((t) => !t.isBusy).toList(growable: false);
    if (warning != null && available.length != targets.length) {
      throw StateError('Aguarde as transferências em andamento.');
    }
    if (_pickingGlobal || available.isEmpty) return false;
    _pickingGlobal = true;
    try {
      final selected = await FilePicker.pickFile(type: FileType.any);
      if (selected == null) return false;
      final size = await selected.length();
      if (size == null) {
        throw StateError('Não foi possível obter o tamanho do arquivo.');
      }
      if (warning != null) {
        if (available.any((target) => target.isBusy)) {
          throw StateError('Aguarde as transferências em andamento.');
        }
        for (final target in available) {
          target._startProtected(
            name: selected.name,
            size: size,
            bytes: selected.readAsByteStream(),
            warning: warning,
            kind: ProtectedContentKind.forExtension(selected.extension),
            channel: channel,
          );
        }
        return true;
      }
      await Future.wait(
        available.map(
          (target) => target.sendFile(
            name: selected.name,
            size: size,
            bytes: selected.readAsByteStream(),
          ),
        ),
      );
      return true;
    } finally {
      _pickingGlobal = false;
    }
  }

  Future<void> pickAndSend() async {
    await pickAndSendToTargets([this]);
  }

  void sendProtectedText({
    required String text,
    required ContentWarning warning,
    String? channel,
  }) {
    if (isBusy) throw StateError('Já existe um envio protegido em andamento.');
    final bytes = utf8.encode(text);
    if (bytes.length > _maxProtectedTextBytes) {
      throw ArgumentError('O texto protegido é longo demais.');
    }
    _startProtected(
      name: '',
      size: bytes.length,
      bytes: Stream.value(bytes),
      warning: warning,
      kind: ProtectedContentKind.text,
      channel: channel,
    );
  }

  void _startProtected({
    required String name,
    required int size,
    required Stream<List<int>> bytes,
    required ContentWarning warning,
    required ProtectedContentKind kind,
    required String? channel,
  }) {
    unawaited(
      sendFile(
        name: name,
        size: size,
        bytes: bytes,
        warning: warning,
        kind: kind,
        channel: channel,
      ).catchError((Object _) {
        if (!_closed) notice('Não foi possível concluir o envio protegido.');
      }),
    );
  }

  void _updateProtected(
    ProtectedTransfer transfer,
    ProtectedTransferState state, {
    String? result,
  }) {
    transfer
      .._state = state
      .._result = result;
    onProtectedTransfer?.call(transfer);
  }

  void decideProtected(ProtectedTransfer transfer, {required bool accept}) {
    final consent = _consent;
    if (identical(transfer, _protectedIncoming) &&
        consent != null &&
        !consent.isCompleted) {
      consent.complete(accept);
      _updateProtected(
        transfer,
        accept
            ? ProtectedTransferState.receiving
            : ProtectedTransferState.declined,
      );
    }
  }

  /// Streams the source without collecting the complete file in memory.
  Future<void> sendFile({
    required String name,
    required int size,
    required Stream<List<int>> bytes,
    ContentWarning? warning,
    ProtectedContentKind kind = ProtectedContentKind.file,
    String? channel,
  }) async {
    if (_closed || _outgoing != null) {
      throw StateError('Transferência indisponível.');
    }
    if (size < 0) throw ArgumentError.value(size);
    if (warning != null &&
        kind == ProtectedContentKind.text &&
        size > _maxProtectedTextBytes) {
      throw ArgumentError('O texto protegido é longo demais.');
    }
    _outgoing =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final generation = _generation;
    _sequence = 0;
    _window = 1;
    final transfer = warning == null
        ? null
        : ProtectedTransfer._(
            id: _outgoing!,
            warning: warning,
            kind: kind,
            channel: channel,
            outgoing: true,
          );
    try {
      if (transfer != null) onProtectedTransfer?.call(transfer);
      await _sendPart(
        {
          'op': transfer == null ? 'start' : 'protected_start',
          'name': name,
          'size': size,
          if (transfer != null) ...{
            'warning': transfer.warning.name,
            'kind': transfer.kind.name,
            'channel': transfer.channel,
          },
        },
        selecting: true,
        protected: transfer != null,
      );
      if (transfer != null) {
        _updateProtected(transfer, ProtectedTransferState.receiving);
      }
      Object? failure;
      var sent = 0;
      var batch = <Future<void>>[];
      final buffer = Uint8List(chunkSize);
      var used = 0;
      Future<void> enqueue(List<int> chunk) async {
        if (_closed || generation != _generation) {
          throw StateError('Transferência interrompida.');
        }
        sent += chunk.length;
        if (sent > size) throw StateError('O arquivo mudou durante o envio.');
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
      if (transfer == null) {
        notice('Arquivo enviado: $name');
      } else {
        _updateProtected(transfer, ProtectedTransferState.completed);
      }
    } catch (_) {
      if (transfer != null) {
        _updateProtected(transfer, ProtectedTransferState.unavailable);
      }
      if (!_closed && generation == _generation) {
        try {
          await _frame({'op': 'cancel', 'id': _outgoing});
        } catch (_) {}
      }
      rethrow;
    } finally {
      for (final ack in _pending.values) {
        if (!ack.isCompleted) ack.complete((ok: false, consent: false));
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
        if (frame['seq'] == 0 && frame['window'] == maxWindow) {
          _window = maxWindow;
        }
        ack.complete((
          ok: frame['ok'] == true,
          consent: frame['consent'] == true,
        ));
      }
      return;
    }
    if (frame['op'] == 'cancel' && frame['id'] == _protectedIncoming?.id) {
      final cancel = _protectedCancel;
      if (cancel != null && !cancel.isCompleted) cancel.complete();
    }
    if ((frame['op'] == 'chunk' || frame['op'] == 'end') &&
        frame['id'] == _protectedIncoming?.id &&
        _next == 0) {
      return;
    }
    if (_queued >= maxWindow * 2 + 8) {
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
        if (!_closed && generation == _generation) {
          await _receiveFrame(frame, generation);
        }
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
      if (op == 'start' || op == 'protected_start') {
        if (_incoming != null ||
            id is! String ||
            id.length > 80 ||
            !RegExp(r'^[0-9]+-[0-9]+$').hasMatch(id) ||
            seq != 0 ||
            frame['name'] is! String ||
            frame['size'] is! int ||
            (frame['size'] as int) < 0) {
          await _frame({'op': 'ack', 'id': id, 'seq': seq, 'ok': false});
          return;
        }
        _incoming = id;
        _next = 0;
        _expected = frame['size'] as int;
        if (op == 'protected_start' && !await _requestConsent(frame, id)) {
          await _discard();
          if (!_closed && generation == _generation) {
            await _frame({'op': 'ack', 'id': id, 'seq': seq, 'ok': false});
          }
          return;
        }
        if (_closed ||
            generation != _generation ||
            _protectedCancel?.isCompleted == true) {
          await _discard();
          return;
        }
        final name = (frame['name'] as String)
            .substring(0, min((frame['name'] as String).length, 120))
            .split(RegExp(r'[/\\]'))
            .last
            .replaceAll(RegExp(r'[^a-zA-Z0-9._ -]'), '_');
        if (_protectedIncoming?.kind == ProtectedContentKind.text) {
          _protectedText = BytesBuilder(copy: false);
        } else {
          final transfer = _protectedIncoming;
          final String? directory;
          if (transfer != null && transfer.kind.isMedia) {
            final root = await _protectedCacheDirectory();
            final cache = await root.createTemp('nexora-protected-');
            transfer._cacheDirectory = cache;
            directory = cache.path;
          } else {
            directory = await Future.any<String?>([
              _chooseDirectory(name),
              _abortSignal.future.then<String?>((_) => null),
              if (_protectedCancel case final cancel?)
                cancel.future.then<String?>((_) => null),
            ]);
          }
          if (directory == null ||
              _closed ||
              generation != _generation ||
              _protectedCancel?.isCompleted == true) {
            await _discard();
            if (!_closed) {
              await _frame({'op': 'ack', 'id': id, 'seq': seq, 'ok': false});
            }
            return;
          }
          final destination = File(
            '$directory${Platform.pathSeparator}nexora-$id-$name',
          );
          await destination.create(exclusive: true);
          _partial = destination;
          _output = await destination.open(mode: FileMode.writeOnly);
          if (_protectedIncoming == null) notice('Recebendo arquivo: $name');
        }
        if (_closed ||
            generation != _generation ||
            _protectedCancel?.isCompleted == true) {
          await _discard();
          return;
        }
        _received = 0;
        _next = 1;
      } else {
        final text = _protectedText;
        if (id != _incoming ||
            seq != _next ||
            (_output == null && text == null)) {
          await _frame({'op': 'ack', 'id': id, 'seq': seq, 'ok': false});
          return;
        }
        if (op == 'chunk') {
          final bytes = base64Decode(frame['data'] as String);
          if (bytes.length > chunkSize ||
              _received + bytes.length > _expected) {
            throw const FormatException('Parte inválida.');
          }
          if (text == null) {
            await _output!.writeFrom(bytes);
          } else {
            text.add(bytes);
          }
          _received += bytes.length;
        } else if (op == 'end') {
          if (_received != _expected) {
            throw const FormatException('Arquivo incompleto.');
          }
          await _output?.flush();
          await _output?.close();
          _output = null;
          final transfer = _protectedIncoming;
          if (transfer == null) {
            notice('Arquivo recebido: ${_partial!.path}');
          } else {
            _updateProtected(
              transfer,
              ProtectedTransferState.completed,
              result: text == null
                  ? _partial!.path
                  : utf8.decode(text.takeBytes()),
            );
          }
          _partial = null;
          _incoming = null;
          _protectedIncoming = null;
          _protectedText = null;
          _protectedCancel = null;
        } else {
          throw const FormatException('Operação inválida.');
        }
        _next++;
      }
      _idle?.cancel();
      if (_incoming != null) {
        _idle = Timer(
          const Duration(minutes: 5),
          () => unawaited(_receiving.run(_discard)),
        );
      }
      await _frame({
        'op': 'ack',
        'id': id,
        'seq': seq,
        'ok': true,
        'window': maxWindow,
        if (op == 'protected_start') 'consent': true,
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

  Future<bool> _requestConsent(Map<String, dynamic> frame, String id) async {
    final warning = ContentWarning.values
        .where((item) => item.name == frame['warning'])
        .firstOrNull;
    final kind = ProtectedContentKind.values
        .where((item) => item.name == frame['kind'])
        .firstOrNull;
    final channel = frame['channel'];
    if (onProtectedTransfer == null ||
        warning == null ||
        kind == null ||
        (channel != null && (channel is! String || channel.length > 256)) ||
        (kind == ProtectedContentKind.text &&
            _expected > _maxProtectedTextBytes)) {
      return false;
    }

    final transfer = ProtectedTransfer._(
      id: id,
      warning: warning,
      kind: kind,
      outgoing: false,
      channel: channel as String?,
    );
    final consent = _consent = Completer<bool>();
    final cancel = _protectedCancel = Completer<void>();
    _protectedIncoming = transfer;
    onProtectedTransfer?.call(transfer);
    try {
      return await Future.any<bool>([
        consent.future,
        cancel.future.then((_) => false),
        _abortSignal.future.then((_) => false),
      ]).timeout(const Duration(minutes: 5), onTimeout: () => false);
    } finally {
      _consent = null;
    }
  }

  Future<void> _discard() async {
    _idle?.cancel();
    final output = _output;
    final partial = _partial;
    _output = null;
    _partial = null;
    _incoming = null;
    final transfer = _protectedIncoming;
    _protectedIncoming = null;
    _protectedCancel = null;
    _protectedText = null;
    if (transfer != null && transfer.state != ProtectedTransferState.declined) {
      _updateProtected(transfer, ProtectedTransferState.unavailable);
    }
    try {
      try {
        await output?.close();
      } finally {
        if (partial != null && await partial.exists()) await partial.delete();
      }
    } catch (_) {
      notice(
        'Não foi possível remover o arquivo parcial. Confira a pasta escolhida.',
      );
    } finally {
      await transfer?.clearCachedContent();
    }
  }

  Future<void> abort() async {
    _generation++;
    _abortSignal.complete();
    _abortSignal = Completer<void>();
    for (final ack in _pending.values) {
      if (!ack.isCompleted) ack.complete((ok: false, consent: false));
    }
    await _receiving.run(_discard);
  }

  Future<void> close() async {
    _closed = true;
    await abort();
  }
}
