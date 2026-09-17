import '../../domain/entities/work.dart';
import 'provider_models.dart';
import 'work_identity_system.dart';

/// Higienização e normalização de metadata externa.
class MetadataNormalizer {
  MetadataNormalizer._();

  static final RegExp _htmlTagRegex = RegExp(r'<[^>]*>', multiLine: true);
  static final RegExp _whitespaceRegex = RegExp(r'[\s\u00A0\u200B\uFEFF]+');
  static final RegExp _controlCharsRegex = RegExp(r'[\x00-\x1F\x7F]');

  static String sanitizeText(String? input) {
    if (input == null) return '';
    var text = input.replaceAll(_htmlTagRegex, ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'");
    text = text.replaceAll(_controlCharsRegex, '');
    return text.replaceAll(_whitespaceRegex, ' ').trim();
  }

  static ({String title, String? subtitle}) normalizeTitle(
    String rawTitle, [
    String? rawSubtitle,
  ]) {
    var mainTitle = sanitizeText(rawTitle);
    final cleanSub = rawSubtitle == null ? null : sanitizeText(rawSubtitle);
    const separators = [': ', ' — ', ' - ', ' | '];

    if (cleanSub != null && cleanSub.isNotEmpty) {
      if (mainTitle.contains(cleanSub)) {
        final index = mainTitle.indexOf(cleanSub);
        var cutIndex = index;
        for (final separator in separators) {
          if (index >= separator.length &&
              mainTitle.substring(index - separator.length, index) ==
                  separator) {
            cutIndex = index - separator.length;
            break;
          }
        }
        mainTitle = mainTitle.substring(0, cutIndex).trim();
      }
      return (
        title: mainTitle.isNotEmpty ? mainTitle : cleanSub,
        subtitle: cleanSub,
      );
    }

    for (final separator in separators) {
      final index = mainTitle.indexOf(separator);
      if (index > 0 && index < mainTitle.length - separator.length) {
        final title = mainTitle.substring(0, index).trim();
        final subtitle = mainTitle.substring(index + separator.length).trim();
        if (title.isNotEmpty && subtitle.isNotEmpty) {
          return (title: title, subtitle: subtitle);
        }
      }
    }
    return (title: mainTitle, subtitle: null);
  }

  static String normalizeAuthor(List<String> rawAuthors) {
    if (rawAuthors.isEmpty) return 'Autor Desconhecido';
    final cleaned = <String>[];
    for (final author in rawAuthors) {
      var name = sanitizeText(author);
      if (name.isEmpty) continue;
      name = name.replaceAll(
        RegExp(r'^(por|by|autor:)\s+', caseSensitive: false),
        '',
      );
      if (name.contains(',') && !name.contains(';')) {
        final parts = name.split(',').map((part) => part.trim()).toList();
        if (parts.length == 2 && parts.every((part) => part.isNotEmpty)) {
          name = '${parts[1]} ${parts[0]}';
        }
      }
      if (name.isNotEmpty && !cleaned.contains(name)) cleaned.add(name);
    }
    return cleaned.isEmpty ? 'Autor Desconhecido' : cleaned.join(', ');
  }

  /// Ausência ou idioma fora do domínio principal permanece indeterminado.
  static String normalizeLanguage(String? rawLanguage) {
    if (rawLanguage == null || rawLanguage.trim().isEmpty) return 'und';
    final clean = rawLanguage.trim().toLowerCase().replaceAll('_', '-');
    if (clean.startsWith('pt') ||
        clean == 'por' ||
        clean.contains('portugues') ||
        clean.contains('portuguese')) {
      return 'pt-BR';
    }
    if (clean.startsWith('en') ||
        clean == 'eng' ||
        clean.contains('ingles') ||
        clean.contains('english')) {
      return 'en';
    }
    return 'und';
  }

  static String? normalizeIsbn(String? rawIsbn) {
    if (rawIsbn == null) return null;
    final cleaned = rawIsbn
        .replaceAll(RegExp(r'[^0-9X]', caseSensitive: false), '')
        .toUpperCase();
    return cleaned.length == 10 || cleaned.length == 13 ? cleaned : null;
  }

  static NormalizedWorkMetadata normalize(ExternalWorkMetadata external) {
    final normalizedTitle = normalizeTitle(external.title, external.subtitle);
    final author = normalizeAuthor(external.authors);
    final language = normalizeLanguage(external.language);
    final isbn = normalizeIsbn(external.isbn);
    final description = sanitizeText(external.description);
    final workKey = WorkIdentitySystem.generateWorkKey(
      title: normalizedTitle.title,
      author: author,
      isbn: isbn,
    );
    final editionId =
        'ed-${external.providerId}-${external.externalId}-${external.format.extension}';
    final now = DateTime.now();
    final remoteUrl = external.downloadUrl;
    final hasRemoteContent =
        remoteUrl != null &&
        external.format != WorkFormat.unknown &&
        (remoteUrl.startsWith('https://') || remoteUrl.startsWith('http://'));
    final assets = hasRemoteContent
        ? <ContentAsset>[
            ContentAsset(
              id: 'asset-${external.providerId}-${external.externalId}-${external.format.extension}',
              editionId: editionId,
              format: external.format,
              status: ContentAssetStatus.remoteAvailable,
              remoteUrl: remoteUrl,
              mediaType: external.extraMetadata['mediaType']?.toString(),
              fileSize: external.fileSizeBytes,
              checksum: external.extraMetadata['checksum']?.toString(),
              checksumAlgorithm: external.extraMetadata['checksumAlgorithm']
                  ?.toString(),
              source: external.providerId,
              createdAt: now,
              updatedAt: now,
            ),
          ]
        : const <ContentAsset>[];

    final edition = WorkEdition(
      id: editionId,
      workId: 'work-$workKey',
      format: external.format,
      fileSize: external.fileSizeBytes,
      pageCount: external.pageCount,
      downloadUrl: remoteUrl,
      providerId: external.providerId,
      externalId: external.externalId,
      language: language,
      originalTitle: sanitizeText(external.title),
      contentAssets: assets,
    );

    return NormalizedWorkMetadata(
      workKey: workKey,
      title: normalizedTitle.title,
      subtitle: normalizedTitle.subtitle,
      author: author,
      description: description.isEmpty ? null : description,
      primaryLanguage: language,
      type: external.type,
      series: external.series == null ? null : sanitizeText(external.series),
      volume: external.volume == null ? null : sanitizeText(external.volume),
      publisher: external.publisher == null
          ? null
          : sanitizeText(external.publisher),
      publishedDate: external.publishedDate == null
          ? null
          : sanitizeText(external.publishedDate),
      isbn: isbn,
      coverUrl: external.coverUrl,
      editions: [edition],
      confidenceScore: 1,
    );
  }

  static String normalizeSearchTerm(String text) {
    var result = text.toLowerCase().trim();
    const diacriticsMap = {
      'á': 'a',
      'à': 'a',
      'ã': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'õ': 'o',
      'ô': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
      'ñ': 'n',
    };
    diacriticsMap.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    result = result.replaceAll(RegExp(r'[\-_,.:;!?()\/]'), ' ');
    return result.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
