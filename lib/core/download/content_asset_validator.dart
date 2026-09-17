import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../../domain/entities/work.dart';

/// Resultado da validação de um arquivo de conteúdo.
class AssetValidationResult {
  final bool isValid;
  final String? error;
  final String? detectedMediaType;
  final int fileSize;
  final String? checksumSha256;

  const AssetValidationResult({
    required this.isValid,
    this.error,
    this.detectedMediaType,
    this.fileSize = 0,
    this.checksumSha256,
  });

  AssetValidationResult copyWith({
    bool? isValid,
    String? error,
    String? detectedMediaType,
    int? fileSize,
    String? checksumSha256,
  }) {
    return AssetValidationResult(
      isValid: isValid ?? this.isValid,
      error: error ?? this.error,
      detectedMediaType: detectedMediaType ?? this.detectedMediaType,
      fileSize: fileSize ?? this.fileSize,
      checksumSha256: checksumSha256 ?? this.checksumSha256,
    );
  }

  static const invalid = AssetValidationResult(
    isValid: false,
    error: 'Arquivo inválido',
  );
}

/// Validador de integridade de conteúdo baixado.
///
/// Nunca confia apenas na extensão: valida assinatura (magic bytes),
/// container mínimo e coerência de tamanho quando o servidor informa.
class ContentAssetValidator {
  const ContentAssetValidator();

  Future<AssetValidationResult> validateFile(
    File file,
    WorkFormat format, {
    int? expectedSize,
    String? expectedChecksumSha256,
    String? expectedChecksum,
    String? checksumAlgorithm,
  }) async {
    if (!await file.exists()) {
      return AssetValidationResult.invalid.copyWith(
        error: 'Arquivo não encontrado',
      );
    }

    final bytes = await file.readAsBytes();
    final size = bytes.length;

    if (expectedSize != null &&
        expectedSize > 0 &&
        size < expectedSize * 0.95) {
      return AssetValidationResult(
        isValid: false,
        error:
            'Arquivo incompleto: esperado ~$expectedSize bytes, recebido $size.',
        fileSize: size,
      );
    }

    final check = checkSignature(bytes, format);
    if (!check.isValid) return check;

    final checksum = expectedChecksum ?? expectedChecksumSha256;
    final algorithm =
        (checksumAlgorithm ??
                (expectedChecksumSha256 != null ? 'sha256' : null))
            ?.toLowerCase();
    if (checksum != null && checksum.isNotEmpty) {
      final actual = _digest(bytes, algorithm);
      if (actual == null) {
        return AssetValidationResult(
          isValid: false,
          error: 'Algoritmo de checksum não suportado: $algorithm.',
          fileSize: size,
        );
      }
      if (actual.toLowerCase() != checksum.trim().toLowerCase()) {
        return AssetValidationResult(
          isValid: false,
          error: 'Checksum $algorithm divergente.',
          fileSize: size,
          checksumSha256: sha256.convert(bytes).toString(),
        );
      }
    }

    return AssetValidationResult(
      isValid: true,
      detectedMediaType: check.detectedMediaType,
      fileSize: size,
      checksumSha256: sha256.convert(bytes).toString(),
    );
  }

  String? _digest(List<int> bytes, String? algorithm) {
    switch (algorithm) {
      case 'md5':
        return md5.convert(bytes).toString();
      case 'sha1':
      case 'sha-1':
        return sha1.convert(bytes).toString();
      case 'sha256':
      case 'sha-256':
        return sha256.convert(bytes).toString();
      default:
        return null;
    }
  }

  /// Verifica assinatura de arquivo e validade mínima de container.
  AssetValidationResult checkSignature(List<int> bytes, WorkFormat format) {
    switch (format) {
      case WorkFormat.epub:
      case WorkFormat.cbz:
        if (!_looksLikeZip(bytes)) {
          return const AssetValidationResult(
            isValid: false,
            error: 'Arquivo não é um ZIP/EPUB/CBZ válido.',
          );
        }
        var valid = true;
        String? message;
        try {
          final archive = ZipDecoder().decodeBytes(bytes, verify: true);
          valid = archive.isNotEmpty;
          if (!valid) message = 'Container ZIP vazio.';
        } catch (_) {
          valid = false;
          message = 'Container ZIP corrompido.';
        }
        return AssetValidationResult(
          isValid: valid,
          error: message,
          detectedMediaType: 'application/zip',
          fileSize: bytes.length,
        );

      case WorkFormat.txt:
        return AssetValidationResult(
          isValid: true,
          detectedMediaType: 'text/plain',
          fileSize: bytes.length,
        );

      case WorkFormat.pdf:
        if (!_startsWith(bytes, [0x25, 0x50, 0x44, 0x46])) {
          return const AssetValidationResult(
            isValid: false,
            error: 'Arquivo não é um PDF (assinatura %PDF ausente).',
          );
        }
        return AssetValidationResult(
          isValid: true,
          detectedMediaType: 'application/pdf',
          fileSize: bytes.length,
        );

      case WorkFormat.cbr:
        // RAR (Rar!/Rar4/Rar5)
        final isRar =
            _startsWith(bytes, [0x52, 0x61, 0x72, 0x21]) ||
            _startsWith(bytes, [0x52, 0x61, 0x72, 0x30]) ||
            _startsWith(bytes, [0x52, 0x61, 0x72, 0x35]);
        if (!isRar) {
          return const AssetValidationResult(
            isValid: false,
            error: 'Arquivo não é um RAR/CBR válido.',
          );
        }
        return AssetValidationResult(
          isValid: true,
          detectedMediaType: 'application/vnd.comicbook-rar',
          fileSize: bytes.length,
        );

      case WorkFormat.images:
      case WorkFormat.unknown:
        // Assinatura de imagem genérica (JPEG/PNG/WebP/GIF/BMP)
        final isImage =
            _startsWith(bytes, [0xFF, 0xD8, 0xFF]) ||
            _startsWith(bytes, [0x89, 0x50, 0x4E, 0x47]) ||
            _startsWith(bytes, [0x47, 0x49, 0x46, 0x38]) ||
            _startsWith(bytes, [0x42, 0x4D]) ||
            _startsWith(bytes, [0x52, 0x49, 0x46, 0x46]);
        if (!isImage) {
          return const AssetValidationResult(
            isValid: false,
            error: 'Arquivo não é uma imagem reconhecida.',
          );
        }
        return AssetValidationResult(
          isValid: true,
          detectedMediaType: 'image',
          fileSize: bytes.length,
        );
    }
  }

  bool _looksLikeZip(List<int> bytes) {
    return _startsWith(bytes, [0x50, 0x4B, 0x03, 0x04]) ||
        _startsWith(bytes, [0x50, 0x4B, 0x05, 0x06]) ||
        _startsWith(bytes, [0x50, 0x4B, 0x07, 0x08]);
  }

  bool _startsWith(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var i = 0; i < signature.length; i++) {
      if (bytes[i] != signature[i]) return false;
    }
    return true;
  }

  /// Extensão esperada vs. mime do servidor (melhor esforço, sem bloquear).
  String? validateExtensionVsContent(String path, String? mimeType) {
    final ext = p.extension(path).replaceAll('.', '').toLowerCase();
    final mime = mimeType?.toLowerCase() ?? '';
    if (mime.isEmpty) return null;
    const expected = {
      'epub': 'epub+zip',
      'zip': 'zip',
      'cbz': 'comicbook',
      'pdf': 'pdf',
      'txt': 'text',
    };
    final key = expected[ext];
    if (key == null) return null;
    if (mime.contains(key)) return null;
    return 'Extensão $ext divere do Content-Type $mimeType detectado pelo servidor.';
  }
}
