import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/errors/nova_errors.dart';
import 'package:vantareader/core/logging/app_logger.dart';
import 'package:vantareader/core/network/network_client.dart';
import 'package:vantareader/core/security/crypto_vault.dart';
import 'package:vantareader/core/storage/storage_manager.dart';

void main() {
  group('Fase P — Auditoria de Segurança & Hardening', () {
    group('1. CryptoVault — Cifragem AES-256 e Integridade HMAC', () {
      late CryptoVault vault;

      setUp(() {
        vault = CryptoVault();
      });

      test('gera chaves aleatórias de 256 bits com entropia criptográfica', () {
        final key1 = CryptoVault.generateKey();
        final key2 = CryptoVault.generateKey();

        expect(key1.bytes.length, equals(32));
        expect(key2.bytes.length, equals(32));
        expect(key1.bytes, isNot(equals(key2.bytes)));
      });

      test('deriva chave determinística com PBKDF2/SHA-256', () {
        final derived1 = CryptoVault.deriveKey(
          secret: 'senhaSuperSecreta',
          salt: 'salt1234',
        );
        final derived2 = CryptoVault.deriveKey(
          secret: 'senhaSuperSecreta',
          salt: 'salt1234',
        );
        final derivedDiff = CryptoVault.deriveKey(
          secret: 'senhaSuperSecreta',
          salt: 'outroSalt',
        );

        expect(derived1.bytes.length, equals(32));
        expect(derived1.bytes, equals(derived2.bytes));
        expect(derived1.bytes, isNot(equals(derivedDiff.bytes)));

        expect(
          () => CryptoVault.deriveKey(secret: '', salt: 'salt'),
          throwsA(isA<NovaException>()),
        );
      });

      test(
        'cifra e decifra texto puro com AES-256-CBC e IV dinâmico único',
        () {
          const plainText =
              'Dados confidenciais do usuário local do NovaReader 2026';
          final encrypted1 = vault.encryptString(plainText);
          final encrypted2 = vault.encryptString(plainText);

          // IVs aleatórios geram ciphertexts distintos para o mesmo plaintext
          expect(encrypted1, isNot(equals(encrypted2)));
          expect(encrypted1, contains(':'));

          final decrypted1 = vault.decryptString(encrypted1);
          final decrypted2 = vault.decryptString(encrypted2);

          expect(decrypted1, equals(plainText));
          expect(decrypted2, equals(plainText));
        },
      );

      test(
        'rejeita payload malformado ou adulterado na decifragem de texto',
        () {
          expect(
            () => vault.decryptString('payloadSemSeparador'),
            throwsA(isA<NovaException>()),
          );

          final valid = vault.encryptString('teste');
          final parts = valid.split(':');
          final tampered =
              '${parts[0]}:YWJjZGVmZ2hpams='; // ciphertext adulterado

          expect(
            () => vault.decryptString(tampered),
            throwsA(isA<NovaException>()),
          );
        },
      );

      test(
        'cifra e decifra bytes binários com integridade e preservação de dados',
        () {
          final originalBytes = Uint8List.fromList(
            List.generate(256, (i) => i % 256),
          );
          final encryptedBytes = vault.encryptBytes(originalBytes);

          expect(encryptedBytes.length, greaterThan(originalBytes.length + 16));
          expect(encryptedBytes, isNot(equals(originalBytes)));

          final decryptedBytes = vault.decryptBytes(encryptedBytes);
          expect(decryptedBytes, equals(originalBytes));
        },
      );

      test('gera e verifica assinaturas HMAC-SHA256 em tempo constante', () {
        final data = Uint8List.fromList(utf8.encode('Mensagem a ser assinada'));
        final signature = vault.sign(data);

        expect(
          signature.length,
          equals(64),
        ); // SHA-256 hex string tem 64 caracteres
        expect(vault.verifySignature(data, signature), isTrue);

        final tamperedData = Uint8List.fromList(
          utf8.encode('Mensagem modificada'),
        );
        expect(vault.verifySignature(tamperedData, signature), isFalse);

        final invalidSignature = signature.replaceRange(0, 4, '0000');
        expect(vault.verifySignature(data, invalidSignature), isFalse);
      });

      test(
        'envelope E2EE: cria e abre pacote seguro ponta a ponta com sucesso',
        () {
          final sharedKey = CryptoVault.generateKey();
          final rawData = Uint8List.fromList(
            utf8.encode('Pacote de sincronização ponta a ponta'),
          );

          final package = vault.createSecurePackage(
            payload: rawData,
            senderId: 'device-peer-alpha',
            sharedKey: sharedKey,
          );

          expect(package['version'], equals('1.0'));
          expect(package['cipher'], equals('AES-256-CBC-HMAC-SHA256'));
          expect(package['sender_id'], equals('device-peer-alpha'));
          expect(package['payload'], isNotNull);
          expect(package['signature'], isNotNull);

          final opened = vault.openSecurePackage(
            package: package,
            sharedKey: sharedKey,
          );

          expect(opened, equals(rawData));
        },
      );

      test(
        'envelope E2EE: rejeita pacote adulterado por terceiro (Man-in-the-Middle)',
        () {
          final sharedKey = CryptoVault.generateKey();
          final rawData = Uint8List.fromList(utf8.encode('Dados sensíveis'));

          final package = vault.createSecurePackage(
            payload: rawData,
            senderId: 'device-peer-alpha',
            sharedKey: sharedKey,
          );

          // Ataque: alteração do payload cifrado em trânsito
          final corruptedPayload = base64Encode(
            Uint8List.fromList([
              1,
              2,
              3,
              4,
              5,
              6,
              7,
              8,
              9,
              10,
              11,
              12,
              13,
              14,
              15,
              16,
              17,
              18,
            ]),
          );
          package['payload'] = corruptedPayload;

          expect(
            () =>
                vault.openSecurePackage(package: package, sharedKey: sharedKey),
            throwsA(
              isA<NovaException>().having(
                (e) => e.message,
                'message',
                contains('Assinatura inválida'),
              ),
            ),
          );
        },
      );
    });

    group('2. StorageManager — Proteção contra Zip Slip e Path Traversal', () {
      late Directory tempDir;
      late StorageManager storage;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('novareader_sec_test_');
        storage = await StorageManager.initialize(customRootPath: tempDir.path);
      });

      tearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });

      test(
        'validateSafeFileName bloqueia caracteres de navegação e traversal',
        () {
          expect(
            () => storage.validateSafeFileName('../escape.txt'),
            throwsA(isA<NovaException>()),
          );
          expect(
            () => storage.validateSafeFileName('sub/file.txt'),
            throwsA(isA<NovaException>()),
          );
          expect(
            () => storage.validateSafeFileName('sub\\file.txt'),
            throwsA(isA<NovaException>()),
          );
          expect(
            () => storage.validateSafeFileName(''),
            throwsA(isA<NovaException>()),
          );
          expect(
            () => storage.validateSafeFileName('   '),
            throwsA(isA<NovaException>()),
          );

          // Nomes seguros não disparam exceção
          expect(
            () => storage.validateSafeFileName('safe_book_123.epub'),
            returnsNormally,
          );
          expect(
            () => storage.validateSafeFileName('comic_capitulo-01.cbz'),
            returnsNormally,
          );
        },
      );

      test(
        'resolveSafeZipEntry resolve subdiretórios válidos dentro do alvo',
        () {
          final safeFile = StorageManager.resolveSafeZipEntry(
            storage.comicsDir,
            'chapters/page01.jpg',
          );
          expect(safeFile.path, contains(storage.comicsDir.path));
          expect(safeFile.path.endsWith('page01.jpg'), isTrue);
        },
      );

      test(
        'resolveSafeZipEntry bloqueia estritamente tentativas de Zip Slip',
        () {
          expect(
            () => StorageManager.resolveSafeZipEntry(
              storage.comicsDir,
              '../../etc/passwd',
            ),
            throwsA(
              isA<NovaException>().having(
                (e) => e.message,
                'message',
                contains('Zip Slip'),
              ),
            ),
          );
          expect(
            () => StorageManager.resolveSafeZipEntry(
              storage.comicsDir,
              '/root/evil.sh',
            ),
            throwsA(
              isA<NovaException>().having(
                (e) => e.message,
                'message',
                contains('Zip Slip'),
              ),
            ),
          );
          expect(
            () => StorageManager.resolveSafeZipEntry(
              storage.comicsDir,
              '..\\windows\\system32',
            ),
            throwsA(
              isA<NovaException>().having(
                (e) => e.message,
                'message',
                contains('Zip Slip'),
              ),
            ),
          );
        },
      );

      test(
        'isSafeZipEntry identifica rapidamente entradas seguras e inseguras',
        () {
          expect(StorageManager.isSafeZipEntry('images/page1.jpg'), isTrue);
          expect(StorageManager.isSafeZipEntry('cover.png'), isTrue);
          expect(StorageManager.isSafeZipEntry('../evil.exe'), isFalse);
          expect(StorageManager.isSafeZipEntry('/absolute/path'), isFalse);
          expect(StorageManager.isSafeZipEntry('\\windows\\path'), isFalse);
          expect(StorageManager.isSafeZipEntry(''), isFalse);
        },
      );
    });

    group('3. AppLogger — Sanitização de Dados Sensíveis e Host Isolation', () {
      test('mascara tokens de autorização e senhas nos logs', () {
        const sensitiveLog1 =
            'Usuário autenticou com Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
        const sensitiveLog2 =
            'Configurando conexão com password: SuperSecretPassword123';
        const sensitiveLog3 = 'Token secreto: token: my_api_key_456';

        final sanitized1 = AppLogger.sanitizeMessage(sensitiveLog1);
        final sanitized2 = AppLogger.sanitizeMessage(sensitiveLog2);
        final sanitized3 = AppLogger.sanitizeMessage(sensitiveLog3);

        expect(sanitized1, contains('Bearer ***REDACTED***'));
        expect(
          sanitized1,
          isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')),
        );

        expect(sanitized2, contains('password: ***REDACTED***'));
        expect(sanitized2, isNot(contains('SuperSecretPassword123')));

        expect(sanitized3, contains('token: ***REDACTED***'));
        expect(sanitized3, isNot(contains('my_api_key_456')));
      });

      test('mascara diretórios pessoais da máquina de desenvolvimento', () {
        const hostLogLinux =
            'Arquivo lido em /home/limaduzz/novareader/books/duna.epub';
        const hostLogMedia =
            'Arquivo carregado de /media/limaduzz/HD 1TB/data.cbz';
        const hostLogWindows = r'Backup em C:\Users\eduardo\AppData\local';

        final sanitizedLinux = AppLogger.sanitizeMessage(hostLogLinux);
        final sanitizedMedia = AppLogger.sanitizeMessage(hostLogMedia);
        final sanitizedWin = AppLogger.sanitizeMessage(hostLogWindows);

        expect(sanitizedLinux, contains('[SANDBOX_USER_DIR]'));
        expect(sanitizedLinux, isNot(contains('/home/limaduzz')));

        expect(sanitizedMedia, contains('[SANDBOX_USER_DIR]'));
        expect(sanitizedMedia, isNot(contains('/media/limaduzz')));

        expect(sanitizedWin, contains('[SANDBOX_USER_DIR]'));
        expect(sanitizedWin, isNot(contains(r'C:\Users\eduardo')));
      });
    });

    group(
      '4. NetworkClient — Hardening de Rede e Bloqueio de Cleartext HTTP',
      () {
        test('permite URLs HTTPS legítimas para servidores remotos', () {
          expect(
            () => NetworkClient.validateUrlSecurity(
              'https://api.github.com/repos',
            ),
            returnsNormally,
          );
          expect(
            () =>
                NetworkClient.validateUrlSecurity('https://gutendex.com/books'),
            returnsNormally,
          );
        });

        test(
          'permite HTTP puro exclusivamente para instâncias de loopback/emulador locais',
          () {
            expect(
              () => NetworkClient.validateUrlSecurity(
                'http://localhost:8080/api',
              ),
              returnsNormally,
            );
            expect(
              () => NetworkClient.validateUrlSecurity(
                'http://127.0.0.1:3000/feed',
              ),
              returnsNormally,
            );
            expect(
              () => NetworkClient.validateUrlSecurity(
                'http://10.0.2.2:8000/mock',
              ),
              returnsNormally,
            );
          },
        );

        test(
          'bloqueia requisições HTTP inseguras para hosts remotos na internet',
          () {
            expect(
              () => NetworkClient.validateUrlSecurity(
                'http://insecure-api.com/books',
              ),
              throwsA(
                isA<NovaException>().having(
                  (e) => e.message,
                  'message',
                  contains('Conexões não criptografadas (HTTP) são proibidas'),
                ),
              ),
            );
          },
        );

        test('rejeita protocolos não suportados ou URIs sem esquema', () {
          expect(
            () =>
                NetworkClient.validateUrlSecurity('ftp://ftp.example.com/file'),
            throwsA(
              isA<NovaException>().having(
                (e) => e.message,
                'message',
                contains('Protocolo de transporte não suportado'),
              ),
            ),
          );
          expect(
            () => NetworkClient.validateUrlSecurity('invalido_sem_esquema'),
            throwsA(isA<NovaException>()),
          );
        });
      },
    );
  });
}
