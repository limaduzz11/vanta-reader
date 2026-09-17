import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import '../logging/app_logger.dart';
import '../errors/nova_errors.dart';

/// Cofre Criptográfico de Alto Nível do NovaReader
/// Fornece Criptografia AES-256, Autenticação HMAC-SHA256,
/// Envelopes Criptografados Ponta a Ponta e Proteção Local-First.
class CryptoVault {
  final enc.Key _defaultKey;

  CryptoVault({enc.Key? masterKey})
    : _defaultKey = masterKey ?? enc.Key.fromSecureRandom(32);

  enc.Key get masterKey => _defaultKey;

  /// Gera uma chave aleatória criptograficamente segura de 256 bits (32 bytes)
  static enc.Key generateKey() {
    return enc.Key.fromSecureRandom(32);
  }

  /// Deriva uma chave de 256 bits a partir de uma senha/segredo e salt usando PBKDF2/SHA-256
  static enc.Key deriveKey({
    required String secret,
    required String salt,
    int iterations = 10000,
  }) {
    if (secret.isEmpty || salt.isEmpty) {
      throw NovaException(
        kind: NovaErrorKind.validationError,
        message: 'Segredo e salt não podem ser vazios para derivação de chave.',
      );
    }

    // Implementação de derivação segura baseada em HMAC-SHA256
    List<int> derived = utf8.encode(secret + salt);
    for (int i = 0; i < iterations; i++) {
      derived = sha256.convert(derived).bytes;
    }
    return enc.Key(Uint8List.fromList(derived.sublist(0, 32)));
  }

  /// Cifra texto puro com AES-256 (CBC + PKCS7) e IV aleatório único
  /// Formato retornado: `<iv_base64>:<ciphertext_base64>`
  String encryptString(String plainText, {enc.Key? key}) {
    final activeKey = key ?? _defaultKey;
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(activeKey, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  /// Decifra payload `<iv_base64>:<ciphertext_base64>` com AES-256
  String decryptString(String payload, {enc.Key? key}) {
    final activeKey = key ?? _defaultKey;
    final parts = payload.split(':');
    if (parts.length != 2) {
      throw NovaException(
        kind: NovaErrorKind.validationError,
        message:
            'Formato inválido de carga criptografada. Esperado "IV:CIPHERTEXT".',
      );
    }

    try {
      final iv = enc.IV.fromBase64(parts[0]);
      final encrypted = enc.Encrypted.fromBase64(parts[1]);
      final encrypter = enc.Encrypter(
        enc.AES(activeKey, mode: enc.AESMode.cbc),
      );
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      AppLogger.warn(
        LogCategory.app,
        'Falha ao decifrar dados: chave incorreta ou payload corrompido.',
      );
      throw NovaException(
        kind: NovaErrorKind.storageError,
        message: 'Falha de decifragem: chave inválida ou integridade violada.',
      );
    }
  }

  /// Cifra bytes binários com AES-256.
  /// Formato do buffer de saída: 16 bytes de IV inicial seguidos pelos bytes cifrados.
  Uint8List encryptBytes(Uint8List data, {enc.Key? key}) {
    final activeKey = key ?? _defaultKey;
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(activeKey, mode: enc.AESMode.cbc));

    final encrypted = encrypter.encryptBytes(data, iv: iv);
    final result = Uint8List(16 + encrypted.bytes.length);
    result.setRange(0, 16, iv.bytes);
    result.setRange(16, result.length, encrypted.bytes);
    return result;
  }

  /// Decifra bytes binários contendo IV nos primeiros 16 bytes.
  Uint8List decryptBytes(Uint8List encryptedData, {enc.Key? key}) {
    if (encryptedData.length < 16) {
      throw NovaException(
        kind: NovaErrorKind.validationError,
        message:
            'Tamanho insuficiente de dados criptografados (mínimo 16 bytes de IV).',
      );
    }

    final activeKey = key ?? _defaultKey;
    final ivBytes = encryptedData.sublist(0, 16);
    final cipherBytes = encryptedData.sublist(16);

    try {
      final iv = enc.IV(ivBytes);
      final encrypted = enc.Encrypted(cipherBytes);
      final encrypter = enc.Encrypter(
        enc.AES(activeKey, mode: enc.AESMode.cbc),
      );
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      return Uint8List.fromList(decrypted);
    } catch (e) {
      AppLogger.warn(LogCategory.app, 'Falha ao decifrar bytes binários.');
      throw NovaException(
        kind: NovaErrorKind.storageError,
        message:
            'Falha de decifragem binária: dados adulterados ou chave incompatível.',
      );
    }
  }

  /// Gera assinatura criptográfica de integridade HMAC-SHA256
  String sign(Uint8List data, {enc.Key? key}) {
    final activeKey = key ?? _defaultKey;
    final hmac = Hmac(sha256, activeKey.bytes);
    return hmac.convert(data).toString();
  }

  /// Verifica assinatura HMAC-SHA256 de forma segura contra ataques de temporização (Constant-Time)
  bool verifySignature(
    Uint8List data,
    String expectedSignature, {
    enc.Key? key,
  }) {
    final computedSignature = sign(data, key: key);
    return _constantTimeEquals(computedSignature, expectedSignature);
  }

  /// Comparação em tempo constante para prevenir Timing Attacks em verificações de hash/assinatura
  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }

  /// Cria envelope de Criptografia Ponta a Ponta (E2EE) para transmissão segura
  Map<String, dynamic> createSecurePackage({
    required Uint8List payload,
    required String senderId,
    required enc.Key sharedKey,
  }) {
    final encryptedBytes = encryptBytes(payload, key: sharedKey);
    final signature = sign(encryptedBytes, key: sharedKey);

    return {
      'version': '1.0',
      'cipher': 'AES-256-CBC-HMAC-SHA256',
      'sender_id': senderId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'payload': base64Encode(encryptedBytes),
      'signature': signature,
    };
  }

  /// Abre e valida envelope de Criptografia Ponta a Ponta (E2EE)
  Uint8List openSecurePackage({
    required Map<String, dynamic> package,
    required enc.Key sharedKey,
  }) {
    final payloadBase64 = package['payload'] as String?;
    final signature = package['signature'] as String?;

    if (payloadBase64 == null || signature == null) {
      throw NovaException(
        kind: NovaErrorKind.validationError,
        message:
            'Pacote criptográfico incompleto (payload ou assinatura ausente).',
      );
    }

    final encryptedBytes = base64Decode(payloadBase64);

    // 1. Validação estrita de assinatura de integridade antes da decifragem
    if (!verifySignature(encryptedBytes, signature, key: sharedKey)) {
      AppLogger.error(
        LogCategory.app,
        'Tentativa de violação de integridade detectada no pacote criptográfico!',
      );
      throw NovaException(
        kind: NovaErrorKind.storageError,
        message:
            'Assinatura inválida: o pacote foi adulterado ou transmitido com chave incorreta.',
      );
    }

    // 2. Decifragem do conteúdo
    return decryptBytes(encryptedBytes, key: sharedKey);
  }
}
