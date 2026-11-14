import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';

/// Algoritmo puro em Dart para geração e renderização de QR Code ISO/IEC 18004.
/// Não depende de bibliotecas nativas ou pacotes externos.
class QrCode {
  final int version;
  final int errorCorrectionLevel; // 1 = L, 0 = M, 3 = Q, 2 = H
  final List<List<bool?>> _modules;
  final int moduleCount;

  QrCode._({
    required this.version,
    required this.errorCorrectionLevel,
    required this.moduleCount,
    required List<List<bool?>> modules,
  }) : _modules = modules;

  bool isDark(int row, int col) => _modules[row][col] ?? false;

  static QrCode encodeText(String text, {int eccLevel = 0}) {
    final data = utf8.encode(text);
    return encodeBytes(data, eccLevel: eccLevel);
  }

  static QrCode encodeBytes(List<int> data, {int eccLevel = 0}) {
    // Escolhe a versão mínima necessária para comportar os dados
    int chosenVersion = 1;
    for (int v = 1; v <= 10; v++) {
      final capacity = _getDataCapacityBytes(v, eccLevel);
      // Byte mode overhead: 4 bits mode + (v <= 9 ? 8 : 16) bits count + 4 bits terminator
      final overheadBits = 4 + (v <= 9 ? 8 : 16) + 4;
      final requiredBytes = ((overheadBits + data.length * 8) + 7) ~/ 8;
      if (requiredBytes <= capacity) {
        chosenVersion = v;
        break;
      }
      if (v == 10) {
        chosenVersion = 10;
      }
    }

    final moduleCount = 17 + 4 * chosenVersion;
    final modules = List.generate(
      moduleCount,
      (_) => List<bool?>.filled(moduleCount, null),
    );

    final qr = QrCode._(
      version: chosenVersion,
      errorCorrectionLevel: eccLevel,
      moduleCount: moduleCount,
      modules: modules,
    );

    // 1. Finder patterns e separadores
    qr._placeFinderPatterns();

    // 2. Alignment patterns
    qr._placeAlignmentPatterns();

    // 3. Timing patterns
    qr._placeTimingPatterns();

    // 4. Dark module fixo
    qr._placeDarkModule();

    // 5. Reserva áreas de informações de formato
    qr._reserveFormatInfoAreas();

    // 6. Prepara codewords de dados e Reed-Solomon ECC
    final codewords = qr._generateCodewords(data, eccLevel);

    // 7. Coloca codewords na matriz
    qr._placeCodewords(codewords);

    // 8. Escolhe a melhor máscara e aplica
    final bestMask = qr._selectBestMask();
    qr._applyMask(bestMask);

    // 9. Escreve informações de formato com a máscara selecionada
    qr._writeFormatInfo(bestMask);

    return qr;
  }

  void _placeFinderPatterns() {
    _placeFinder(0, 0);
    _placeFinder(moduleCount - 7, 0);
    _placeFinder(0, moduleCount - 7);
  }

  void _placeFinder(int row, int col) {
    for (int r = -1; r <= 7; r++) {
      for (int c = -1; c <= 7; c++) {
        final targetR = row + r;
        final targetC = col + c;
        if (targetR < 0 ||
            targetR >= moduleCount ||
            targetC < 0 ||
            targetC >= moduleCount) {
          continue;
        }
        if ((r >= 0 && r <= 6 && (c == 0 || c == 6)) ||
            (c >= 0 && c <= 6 && (r == 0 || r == 6)) ||
            (r >= 2 && r <= 4 && c >= 2 && c <= 4)) {
          _modules[targetR][targetC] = true;
        } else {
          _modules[targetR][targetC] = false;
        }
      }
    }
  }

  void _placeAlignmentPatterns() {
    final positions = _getAlignmentPositions(version);
    for (int i = 0; i < positions.length; i++) {
      for (int j = 0; j < positions.length; j++) {
        final r = positions[i];
        final c = positions[j];
        // Não sobrepõe finders patterns
        if (_modules[r][c] != null) continue;
        for (int dr = -2; dr <= 2; dr++) {
          for (int dc = -2; dc <= 2; dc++) {
            final isDark =
                dr.abs() == 2 || dc.abs() == 2 || (dr == 0 && dc == 0);
            _modules[r + dr][c + dc] = isDark;
          }
        }
      }
    }
  }

  void _placeTimingPatterns() {
    for (int i = 8; i < moduleCount - 8; i++) {
      final dark = i % 2 == 0;
      if (_modules[6][i] == null) _modules[6][i] = dark;
      if (_modules[i][6] == null) _modules[i][6] = dark;
    }
  }

  void _placeDarkModule() {
    _modules[4 * version + 9][8] = true;
  }

  void _reserveFormatInfoAreas() {
    for (int i = 0; i < 9; i++) {
      if (_modules[8][i] == null) _modules[8][i] = false;
      if (_modules[i][8] == null) _modules[i][8] = false;
    }
    for (int i = moduleCount - 8; i < moduleCount; i++) {
      if (_modules[8][i] == null) _modules[8][i] = false;
      if (_modules[i][8] == null) _modules[i][8] = false;
    }
  }

  List<int> _generateCodewords(List<int> data, int eccLevel) {
    final totalCapacity = _getDataCapacityBytes(version, eccLevel);
    final bitBuffer = <int>[];

    void writeBits(int value, int bitLength) {
      for (int i = bitLength - 1; i >= 0; i--) {
        bitBuffer.add((value >> i) & 1);
      }
    }

    // Modo Byte: 0100
    writeBits(4, 4);
    // Contador de caracteres
    final countBits = version <= 9 ? 8 : 16;
    writeBits(data.length, countBits);
    // Dados UTF-8
    for (final b in data) {
      writeBits(b, 8);
    }
    // Terminador (até 4 zeros)
    final remainingBits = totalCapacity * 8 - bitBuffer.length;
    final terminatorLength = min(4, max(0, remainingBits));
    for (int i = 0; i < terminatorLength; i++) {
      bitBuffer.add(0);
    }
    // Pad até múltiplo de 8
    while (bitBuffer.length % 8 != 0) {
      bitBuffer.add(0);
    }
    // Pad bytes 0xEC, 0x11
    final dataBytes = <int>[];
    for (int i = 0; i < bitBuffer.length; i += 8) {
      int byte = 0;
      for (int b = 0; b < 8; b++) {
        byte = (byte << 1) | bitBuffer[i + b];
      }
      dataBytes.add(byte);
    }
    final padBytes = [0xEC, 0x11];
    int padIndex = 0;
    while (dataBytes.length < totalCapacity) {
      dataBytes.add(padBytes[padIndex % 2]);
      padIndex++;
    }

    // Divisão em blocos e cálculo Reed-Solomon ECC
    final blockInfo = _getBlockInfo(version, eccLevel);
    final blocks = <List<int>>[];
    final eccBlocks = <List<int>>[];
    int offset = 0;

    for (final b in blockInfo) {
      final blockData = dataBytes.sublist(offset, offset + b.dataCount);
      offset += b.dataCount;
      blocks.add(blockData);
      eccBlocks.add(_computeReedSolomon(blockData, b.eccCount));
    }

    // Interleave data codewords
    final result = <int>[];
    int maxDataLen = 0;
    for (final b in blocks) {
      if (b.length > maxDataLen) maxDataLen = b.length;
    }
    for (int i = 0; i < maxDataLen; i++) {
      for (final b in blocks) {
        if (i < b.length) result.add(b[i]);
      }
    }

    // Interleave ECC codewords
    int maxEccLen = 0;
    for (final e in eccBlocks) {
      if (e.length > maxEccLen) maxEccLen = e.length;
    }
    for (int i = 0; i < maxEccLen; i++) {
      for (final e in eccBlocks) {
        if (i < e.length) result.add(e[i]);
      }
    }

    return result;
  }

  List<int> _computeReedSolomon(List<int> data, int eccCount) {
    final generator = _rsGenerators[eccCount] ?? _createRsGenerator(eccCount);
    final result = List<int>.filled(eccCount, 0);

    for (final byte in data) {
      final factor = byte ^ result[0];
      for (int i = 0; i < eccCount - 1; i++) {
        result[i] = result[i + 1] ^ _gfMultiply(factor, generator[i]);
      }
      result[eccCount - 1] = _gfMultiply(factor, generator[eccCount - 1]);
    }
    return result;
  }

  void _placeCodewords(List<int> codewords) {
    int byteIdx = 0;
    int bitIdx = 7;
    int col = moduleCount - 1;
    bool upward = true;

    while (col > 0) {
      if (col == 6) col--; // Pula timing pattern vertical
      for (int i = 0; i < moduleCount; i++) {
        final row = upward ? moduleCount - 1 - i : i;
        for (int c = 0; c < 2; c++) {
          final targetCol = col - c;
          if (_modules[row][targetCol] != null) continue;
          bool bit = false;
          if (byteIdx < codewords.length) {
            bit = ((codewords[byteIdx] >> bitIdx) & 1) == 1;
            bitIdx--;
            if (bitIdx < 0) {
              bitIdx = 7;
              byteIdx++;
            }
          }
          _modules[row][targetCol] = bit;
        }
      }
      upward = !upward;
      col -= 2;
    }
  }

  int _selectBestMask() {
    int bestMask = 0;
    int lowestPenalty = 1 << 30;

    for (int mask = 0; mask < 8; mask++) {
      _applyMask(mask);
      _writeFormatInfo(mask);
      final penalty = _calculatePenalty();
      if (penalty < lowestPenalty) {
        lowestPenalty = penalty;
        bestMask = mask;
      }
      _applyMask(mask); // Reverte a máscara
    }
    return bestMask;
  }

  void _applyMask(int mask) {
    for (int r = 0; r < moduleCount; r++) {
      for (int c = 0; c < moduleCount; c++) {
        if (_isFunctionModule(r, c)) continue;
        final condition = switch (mask) {
          0 => (r + c) % 2 == 0,
          1 => r % 2 == 0,
          2 => c % 3 == 0,
          3 => (r + c) % 3 == 0,
          4 => (r ~/ 2 + c ~/ 3) % 2 == 0,
          5 => (r * c) % 2 + (r * c) % 3 == 0,
          6 => ((r * c) % 2 + (r * c) % 3) % 2 == 0,
          7 => ((r + c) % 2 + (r * c) % 3) % 2 == 0,
          _ => false,
        };
        if (condition) {
          _modules[r][c] = !(_modules[r][c] ?? false);
        }
      }
    }
  }

  bool _isFunctionModule(int r, int c) {
    // Finders
    if ((r <= 8 && c <= 8) ||
        (r <= 8 && c >= moduleCount - 8) ||
        (r >= moduleCount - 8 && c <= 8)) {
      return true;
    }
    // Timing
    if (r == 6 || c == 6) return true;
    // Dark module
    if (r == 4 * version + 9 && c == 8) return true;
    // Alignment patterns
    final positions = _getAlignmentPositions(version);
    for (final pr in positions) {
      for (final pc in positions) {
        if ((pr <= 8 && pc <= 8) ||
            (pr <= 8 && pc >= moduleCount - 8) ||
            (pr >= moduleCount - 8 && pc <= 8)) {
          continue;
        }
        if ((r - pr).abs() <= 2 && (c - pc).abs() <= 2) return true;
      }
    }
    return false;
  }

  void _writeFormatInfo(int mask) {
    // 2 bits ECC + 3 bits mask
    final data = (errorCorrectionLevel << 3) | mask;
    // BCH(15, 5)
    int rem = data << 10;
    for (int i = 4; i >= 0; i--) {
      if ((rem >> (i + 10)) & 1 == 1) {
        rem ^= 0x537 << i;
      }
    }
    final formatBits = ((data << 10) | rem) ^ 0x5412;

    for (int i = 0; i < 15; i++) {
      final bit = ((formatBits >> i) & 1) == 1;
      if (i <= 5) {
        _modules[8][i] = bit;
      } else if (i == 6) {
        _modules[8][7] = bit;
      } else if (i <= 8) {
        _modules[8][8 - (i - 7)] = bit;
      } else {
        _modules[14 - i][8] = bit;
      }

      if (i < 7) {
        _modules[moduleCount - 1 - i][8] = bit;
      } else {
        _modules[8][moduleCount - 8 + (i - 7)] = bit;
      }
    }
  }

  int _calculatePenalty() {
    int penalty = 0;
    // Penalidade 1: sequências de 5 ou mais da mesma cor
    for (int r = 0; r < moduleCount; r++) {
      int count = 0;
      bool? last;
      for (int c = 0; c < moduleCount; c++) {
        final current = _modules[r][c];
        if (current == last) {
          count++;
          if (count == 5) {
            penalty += 3;
          } else if (count > 5) {
            penalty += 1;
          }
        } else {
          last = current;
          count = 1;
        }
      }
    }
    for (int c = 0; c < moduleCount; c++) {
      int count = 0;
      bool? last;
      for (int r = 0; r < moduleCount; r++) {
        final current = _modules[r][c];
        if (current == last) {
          count++;
          if (count == 5) {
            penalty += 3;
          } else if (count > 5) {
            penalty += 1;
          }
        } else {
          last = current;
          count = 1;
        }
      }
    }
    return penalty;
  }

  // Aritmética de Galois GF(2^8)
  static final List<int> _gfExp = _initGfExp();
  static final List<int> _gfLog = _initGfLog();

  static List<int> _initGfExp() {
    final exp = List<int>.filled(512, 0);
    int x = 1;
    for (int i = 0; i < 255; i++) {
      exp[i] = x;
      exp[i + 255] = x;
      x <<= 1;
      if (x & 0x100 != 0) x ^= 0x11D;
    }
    return exp;
  }

  static List<int> _initGfLog() {
    final log = List<int>.filled(256, 0);
    for (int i = 0; i < 255; i++) {
      log[_gfExp[i]] = i;
    }
    return log;
  }

  static int _gfMultiply(int x, int y) {
    if (x == 0 || y == 0) return 0;
    return _gfExp[_gfLog[x] + _gfLog[y]];
  }

  static final Map<int, List<int>> _rsGenerators = {};

  static List<int> _createRsGenerator(int count) {
    var poly = [1];
    for (int i = 0; i < count; i++) {
      final next = List<int>.filled(poly.length + 1, 0);
      final factor = _gfExp[i];
      for (int j = 0; j < poly.length; j++) {
        next[j] ^= poly[j];
        next[j + 1] ^= _gfMultiply(poly[j], factor);
      }
      poly = next;
    }
    _rsGenerators[count] = poly.sublist(1);
    return poly.sublist(1);
  }

  static int _getDataCapacityBytes(int v, int ecc) {
    final blocks = _getBlockInfo(v, ecc);
    return blocks.fold<int>(0, (sum, b) => sum + b.dataCount);
  }

  static List<({int dataCount, int eccCount})> _getBlockInfo(int v, int ecc) {
    // Tabelas ISO 18004 para versões 1 a 10 (ecc 0 = M, 1 = L)
    const tableM = [
      [(16, 10)], // v1
      [(28, 16)], // v2
      [(44, 26)], // v3
      [(64, 36)], // v4 (1 bloco)
      [(86, 48)], // v5
      [(108, 64)], // v6
      [(124, 72)], // v7
      [(154, 88)], // v8
      [(182, 110)], // v9
      [(216, 130)], // v10
    ];
    const tableL = [
      [(19, 7)], // v1
      [(34, 10)], // v2
      [(55, 15)], // v3
      [(80, 20)], // v4
      [(108, 26)], // v5
      [(136, 36)], // v6
      [(156, 40)], // v7
      [(194, 48)], // v8
      [(232, 60)], // v9
      [(274, 72)], // v10
    ];

    final source = ecc == 1 ? tableL : tableM;
    final row = source[min(v - 1, source.length - 1)];
    return row.map((entry) => (dataCount: entry.$1, eccCount: entry.$2)).toList();
  }

  static List<int> _getAlignmentPositions(int v) {
    if (v == 1) return const [];
    const List<List<int>> alignmentTable = [
      <int>[],
      [6, 18],
      [6, 22],
      [6, 26],
      [6, 30],
      [6, 34],
      [6, 22, 38],
      [6, 24, 42],
      [6, 26, 46],
      [6, 28, 50],
    ];
    return alignmentTable[min(v - 1, alignmentTable.length - 1)];
  }
}

/// Widget moderno de renderização de QR Code customizável.
class QrCodeWidget extends StatelessWidget {
  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 220,
    this.foregroundColor,
    this.backgroundColor = Colors.white,
    this.padding = 16,
    this.centerWidget,
  });

  final String data;
  final double size;
  final Color? foregroundColor;
  final Color backgroundColor;
  final double padding;
  final Widget? centerWidget;

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? const Color(0xFF0D1220);
    final qr = QrCode.encodeText(data, eccLevel: 0);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size - padding * 2),
            painter: _QrPainter(qr: qr, color: fg),
          ),
          if (centerWidget != null)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: centerWidget!,
            ),
        ],
      ),
    );
  }
}

class QrCodePainter extends CustomPainter {
  final String data;
  final Color color;
  late final QrCode _qr = QrCode.encodeText(data, eccLevel: 0);

  QrCodePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final moduleSize = size.width / _qr.moduleCount;

    for (int r = 0; r < _qr.moduleCount; r++) {
      for (int c = 0; c < _qr.moduleCount; c++) {
        if (_qr.isDark(r, c)) {
          final rect = Rect.fromLTWH(
            c * moduleSize,
            r * moduleSize,
            moduleSize,
            moduleSize,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(moduleSize * 0.2)),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant QrCodePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}

class _QrPainter extends CustomPainter {
  final QrCode qr;
  final Color color;

  _QrPainter({required this.qr, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final moduleSize = size.width / qr.moduleCount;

    for (int r = 0; r < qr.moduleCount; r++) {
      for (int c = 0; c < qr.moduleCount; c++) {
        if (qr.isDark(r, c)) {
          final rect = Rect.fromLTWH(
            c * moduleSize,
            r * moduleSize,
            moduleSize,
            moduleSize,
          );
          // Cantos ligeiramente suavizados para estética moderna
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(moduleSize * 0.2)),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.qr != qr || oldDelegate.color != color;
}
