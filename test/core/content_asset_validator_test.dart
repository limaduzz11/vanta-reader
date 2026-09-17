import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/download/content_asset_validator.dart';
import 'package:vantareader/domain/entities/work.dart';

import '../support/reader_test_fixtures.dart';

void main() {
  late Directory tempDir;
  late File epubFile;
  late List<int> epubBytes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('vanta_asset_validator_');
    epubBytes = buildTestEpub();
    epubFile = File('${tempDir.path}/fixture.epub');
    await epubFile.writeAsBytes(epubBytes);
  });

  tearDown(() => tempDir.delete(recursive: true));

  test('aceita EPUB íntegro com SHA-1 fornecido pela fonte', () async {
    final result = await const ContentAssetValidator().validateFile(
      epubFile,
      WorkFormat.epub,
      expectedSize: epubBytes.length,
      expectedChecksum: sha1.convert(epubBytes).toString(),
      checksumAlgorithm: 'sha1',
    );

    expect(result.isValid, isTrue);
    expect(result.checksumSha256, sha256.convert(epubBytes).toString());
  });

  test('rejeita arquivo quando checksum diverge', () async {
    final result = await const ContentAssetValidator().validateFile(
      epubFile,
      WorkFormat.epub,
      expectedChecksum: '0000000000000000000000000000000000000000',
      checksumAlgorithm: 'sha1',
    );

    expect(result.isValid, isFalse);
    expect(result.error, contains('Checksum sha1 divergente'));
  });
}
