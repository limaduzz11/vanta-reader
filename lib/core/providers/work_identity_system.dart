import 'dart:math';
import '../../domain/entities/work.dart';
import 'metadata_normalizer.dart';
import 'provider_models.dart';

/// Sistema de Identidade Canônica e Deduplicação de Obras (WorkIdentitySystem)
class WorkIdentitySystem {
  WorkIdentitySystem._();

  static const Set<String> _stopWords = {
    // Português
    'o', 'a', 'os', 'as', 'um', 'uma', 'uns', 'umas',
    'de', 'do', 'da', 'dos', 'das', 'em', 'no', 'na', 'nos', 'nas',
    'e', 'por', 'com', 'livro', 'volume', 'edicao', 'completo',
    // Inglês
    'the', 'an', 'of', 'in', 'on', 'at', 'and', 'to', 'for', 'with', 'by',
    'book', 'vol', 'edition', 'complete',
  };

  /// Mapeamento de títulos canônicos conhecidos entre idiomas (pt-BR <-> en)
  static const Map<String, String> _knownCrossLanguageSynonyms = {
    'dune': 'duna',
    'duna': 'duna',
    'clean code': 'codigo limpo',
    'codigo limpo': 'codigo limpo',
    'foundation': 'fundacao',
    'fundacao': 'fundacao',
    'the end of eternity': 'o fim da eternidade',
    'o fim da eternidade': 'o fim da eternidade',
  };

  /// Remove acentos e diacríticos de strings
  static String removeDiacritics(String str) {
    const withDia = 'ÀÁÂÃÄÅàáâãäåÒÓÔÕÖØòóôõöøÈÉÊËèéêëÌÍÎÏìíîïÙÚÛÜùúûüÝýÿÑñÇç';
    const withoutDia =
        'AAAAAAaaaaaaOOOOOOooooooEEEEeeeeIIIIiiiiUUUUuuuuYyyNnCc';

    var result = str;
    for (int i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }

  /// Gera um slug fonético simplificado e limpo
  static String slugify(String text, {bool filterStopWords = true}) {
    var cleaned = removeDiacritics(text).toLowerCase();
    cleaned = cleaned.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');

    final words = cleaned
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .where((w) => !filterStopWords || !_stopWords.contains(w))
        .toList();

    if (words.isEmpty) {
      // Fallback sem filtro de stopwords
      final fallbackWords = cleaned
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      return fallbackWords.join('_');
    }

    return words.join('_');
  }

  /// Gera a chave canônica determinística de identidade da obra
  static String generateWorkKey({
    required String title,
    required String author,
    String? isbn,
  }) {
    // 1. Prioridade absoluta para ISBN válido
    if (isbn != null) {
      final cleanIsbn = isbn.replaceAll(RegExp(r'[^0-9X]'), '').toUpperCase();
      if (cleanIsbn.length == 10 || cleanIsbn.length == 13) {
        return 'isbn_$cleanIsbn';
      }
    }

    // 2. Normalização do título
    var titleSlug = slugify(title);

    // Mapeamento de sinônimos cross-language comuns
    final normalizedRawTitle = removeDiacritics(title).toLowerCase().trim();
    if (_knownCrossLanguageSynonyms.containsKey(normalizedRawTitle)) {
      titleSlug = slugify(_knownCrossLanguageSynonyms[normalizedRawTitle]!);
    }

    // 3. Normalização do autor (tokens ordenados para ignorar "Frank Herbert" vs "Herbert, Frank")
    final authorTokens =
        removeDiacritics(author)
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty && !_stopWords.contains(t))
            .toList()
          ..sort();

    final authorSlug = authorTokens.join('_');

    if (titleSlug.isEmpty) titleSlug = 'sem_titulo';
    final safeAuthor = authorSlug.isNotEmpty
        ? authorSlug
        : 'autor_desconhecido';

    return '${titleSlug}__$safeAuthor';
  }

  /// Calcula a similaridade entre duas strings usando distância de Levenshtein normalizada (0.0 a 1.0)
  static double calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final str1 = removeDiacritics(s1).toLowerCase().trim();
    final str2 = removeDiacritics(s2).toLowerCase().trim();

    if (str1 == str2) return 1.0;

    final len1 = str1.length;
    final len2 = str2.length;
    final maxLen = max(len1, len2);
    if (maxLen == 0) return 1.0;

    var prev = List<int>.generate(len2 + 1, (i) => i);
    var curr = List<int>.filled(len2 + 1, 0);

    for (var i = 0; i < len1; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < len2; j++) {
        final cost = str1[i] == str2[j] ? 0 : 1;
        curr[j + 1] = min(
          curr[j] + 1, // inserção
          min(
            prev[j + 1] + 1, // deleção
            prev[j] + cost, // substituição
          ),
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    final distance = prev[len2];
    return 1.0 - (distance / maxLen);
  }

  /// Deduplica e mescla uma lista de metadados brutos em obras canônicas unificadas
  static List<Work> deduplicateAndMerge(List<ExternalWorkMetadata> rawItems) {
    if (rawItems.isEmpty) return [];

    // 1. Normaliza cada item
    final normalizedItems = rawItems.map(MetadataNormalizer.normalize).toList();

    // 2. Agrupa por chave canônica exata inicialmente
    final groups = <String, List<NormalizedWorkMetadata>>{};

    for (final item in normalizedItems) {
      groups.putIfAbsent(item.workKey, () => []).add(item);
    }

    // 3. Segunda passagem: Fusão difusa (fuzzy merge) de chaves com alta similaridade
    final mergedKeys =
        <String, String>{}; // mapeia chave derivada -> chave canônica
    final keys = groups.keys.toList();

    for (int i = 0; i < keys.length; i++) {
      final keyA = keys[i];
      final targetKey = mergedKeys[keyA] ?? keyA;

      for (int j = i + 1; j < keys.length; j++) {
        final keyB = keys[j];
        if (mergedKeys.containsKey(keyB)) continue;

        final itemsA = groups[targetKey]!;
        final itemsB = groups[keyB]!;

        // Verifica se autores coincidem
        final authorA = itemsA.first.author;
        final authorB = itemsB.first.author;
        final authorSimilarity = calculateSimilarity(authorA, authorB);

        // Verifica similaridade de título
        final titleA = itemsA.first.title;
        final titleB = itemsB.first.title;
        final titleSimilarity = calculateSimilarity(titleA, titleB);

        // Se mesmo autor (similaridade >= 0.75) e títulos muito parecidos (>= 0.8 ou distância pequena)
        if (authorSimilarity >= 0.75 && titleSimilarity >= 0.75) {
          // Fusão de keyB em targetKey
          itemsA.addAll(itemsB);
          mergedKeys[keyB] = targetKey;
          groups.remove(keyB);
        }
      }
    }

    // 4. Constrói as obras unificadas
    final unifiedWorks = <Work>[];

    for (final entry in groups.entries) {
      final workKey = entry.key;
      final items = entry.value;

      // Seleciona o melhor título (dá preferência a pt-BR se disponível)
      final ptBrItem = items.firstWhere(
        (it) => it.primaryLanguage == 'pt-BR',
        orElse: () => items.first,
      );
      final bestTitle = ptBrItem.title;
      final bestSubtitle = items
          .map((it) => it.subtitle)
          .firstWhere(
            (sub) => sub != null && sub.isNotEmpty,
            orElse: () => null,
          );

      // Seleciona o autor mais completo
      final bestAuthor = items
          .map((it) => it.author)
          .reduce((a, b) => a.length >= b.length ? a : b);

      // Seleciona a descrição mais informativa (mais longa)
      final bestDescription = items
          .map((it) => it.description)
          .where((d) => d != null && d.isNotEmpty)
          .fold<String?>(
            null,
            (prev, curr) =>
                prev == null || curr!.length > prev.length ? curr : prev,
          );

      // Seleciona a melhor capa (primeira não nula)
      final bestCoverUrl = items
          .map((it) => it.coverUrl)
          .firstWhere(
            (url) => url != null && url.isNotEmpty,
            orElse: () => null,
          );

      // Idioma principal sem invenção: pt-BR/en quando comprovados, senão und.
      final primaryLanguage =
          items.any((item) => item.primaryLanguage == 'pt-BR')
          ? 'pt-BR'
          : items.any((item) => item.primaryLanguage == 'en')
          ? 'en'
          : 'und';

      // Combina e deduplica edições de todos os provedores
      final allEditions = <WorkEdition>[];
      final seenEditionKeys = <String>{};

      for (final item in items) {
        for (final ed in item.editions) {
          // Chave única de edição por identidade EXTERNA (nunca por URL remota
          // de metadata, que pode ser mutável). Providência: providerId + externalId.
          final editionKey =
              '${ed.providerId}_${ed.downloadUrl ?? ed.externalId ?? ''}_${ed.format.extension}';
          if (!seenEditionKeys.contains(editionKey)) {
            seenEditionKeys.add(editionKey);
            allEditions.add(ed.copyWith(workId: 'work-$workKey'));
          }
        }
      }

      // Tipo por evidência: qualquer item classificado como COMIC por sua
      // fonte (semântica explícita) classifica a obra como COMIC. Nunca
      // rebaixa: se TODOS os itens são book, permanece book.
      final type = items.any((it) => it.type == WorkType.comic)
          ? WorkType.comic
          : WorkType.book;
      final series = items
          .map((it) => it.series)
          .firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null);
      final volume = items
          .map((it) => it.volume)
          .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
      final publisher = items
          .map((it) => it.publisher)
          .firstWhere((p) => p != null && p.isNotEmpty, orElse: () => null);
      final publishedDate = items
          .map((it) => it.publishedDate)
          .firstWhere((d) => d != null && d.isNotEmpty, orElse: () => null);
      final isbn = items
          .map((it) => it.isbn)
          .firstWhere((i) => i != null && i.isNotEmpty, orElse: () => null);

      final now = DateTime.now();
      unifiedWorks.add(
        Work(
          id: 'work-$workKey',
          workKey: workKey,
          title: bestTitle,
          subtitle: bestSubtitle,
          author: bestAuthor,
          description: bestDescription,
          primaryLanguage: primaryLanguage,
          type: type,
          series: series,
          volume: volume,
          publisher: publisher,
          publishedDate: publishedDate,
          isbn: isbn,
          coverPath: bestCoverUrl,
          editions: allEditions,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    return unifiedWorks;
  }
}
