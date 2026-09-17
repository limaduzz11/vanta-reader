import 'dart:async';
import 'package:vantareader/core/errors/nova_errors.dart';
import 'package:vantareader/core/providers/content_provider.dart';
import 'package:vantareader/core/providers/metadata_normalizer.dart';
import 'package:vantareader/core/providers/provider_models.dart';
import 'package:vantareader/domain/entities/work.dart';

/// Provedor de Conteúdo Simulado (Mock) de Alta Fidelidade para a Fase I
class MockContentProvider implements ContentProvider {
  @override
  String get id => 'mock-content-provider';

  @override
  String get name => 'VANTA Reader Mock Provider';

  @override
  String get version => '1.0.0';

  @override
  ProviderCapabilities get capabilities => const ProviderCapabilities(
    supportsSearch: true,
    supportsDownload: true,
    supportsStreaming: true,
    supportedFormats: {
      WorkFormat.epub,
      WorkFormat.pdf,
      WorkFormat.txt,
      WorkFormat.cbz,
      WorkFormat.images,
    },
    supportedLanguages: {'pt-BR', 'en'},
    rateLimitPerMinute: 120,
  );

  @override
  Duration timeout = const Duration(seconds: 5);

  // Variáveis de controle para testes de isolamento de falhas
  Duration simulatedLatency = Duration.zero;
  bool simulateError = false;
  bool simulateTimeout = false;
  ProviderStatus forcedStatus = ProviderStatus.healthy;

  final List<ExternalWorkMetadata> _mockCatalog = [
    // 1. DUNA (EPUB pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-dune-pt',
      title: 'Duna: Crônicas de Duna — Livro 1',
      subtitle: 'Crônicas de Duna — Livro 1',
      authors: ['Frank Herbert'],
      description:
          'Uma obra-prima da ficção científica que se passa no inóspito planeta desértico Arrakis. O jovem Paul Atreides deve liderar os Fremen em uma batalha épica.',
      language: 'pt-BR',
      type: WorkType.book,
      format: WorkFormat.epub,
      coverUrl: 'mock://covers/dune.jpg',
      downloadUrl: 'mock://download/dune-pt.epub',
      fileSizeBytes: 3145728, // 3.0 MB
      pageCount: 680,
      publisher: 'Editora Aleph',
      publishedDate: '1965',
      isbn: '9788576573135',
      series: 'Crônicas de Duna',
      volume: '1',
    ),

    // 2. DUNA / DUNE (PDF en) - Para testar deduplicação cross-language
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-dune-en',
      title: 'Dune: Volume 1',
      subtitle: 'Volume 1',
      authors: ['Herbert, Frank'],
      description:
          'Set on the desert planet Arrakis, Dune (Duna) is the story of the boy Paul Atreides, heir to a noble family tasked with ruling an inhospitable world.',
      language: 'en',
      type: WorkType.book,
      format: WorkFormat.pdf,
      coverUrl: 'mock://covers/dune-en.jpg',
      downloadUrl: 'mock://download/dune-en.pdf',
      fileSizeBytes: 12582912, // 12.0 MB
      pageCount: 680,
      publisher: 'Chilton Books',
      publishedDate: '1965',
      isbn: '9788576573135',
      series: 'Dune Chronicles',
      volume: '1',
    ),

    // 3. CLEAN CODE (EPUB en)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-cleancode-en',
      title: 'Clean Code: A Handbook of Agile Software Craftsmanship',
      subtitle: 'A Handbook of Agile Software Craftsmanship',
      authors: ['Robert C. Martin'],
      description:
          'Even bad code can function. But if code isn\'t clean, it can bring a development organization to its knees.',
      language: 'en',
      type: WorkType.book,
      format: WorkFormat.epub,
      coverUrl: 'mock://covers/cleancode.jpg',
      downloadUrl: 'mock://download/cleancode.epub',
      fileSizeBytes: 5452595, // 5.2 MB
      pageCount: 464,
      publisher: 'Prentice Hall',
      publishedDate: '2008',
      isbn: '9780132350884',
      series: 'Robert C. Martin Series',
    ),

    // 4. CÓDIGO LIMPO (PDF pt-BR) - Para testar deduplicação
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-cleancode-pt',
      title: 'Código Limpo: Habilidades Práticas do Agile Software',
      subtitle: 'Habilidades Práticas do Agile Software',
      authors: ['Martin, Robert C.'],
      description:
          'Mesmo um código ruim pode funcionar. Mas se ele não for limpo, pode acabar com uma empresa de desenvolvimento.',
      language: 'pt-BR',
      type: WorkType.book,
      format: WorkFormat.pdf,
      coverUrl: 'mock://covers/codigolimpo.jpg',
      downloadUrl: 'mock://download/codigolimpo.pdf',
      fileSizeBytes: 8388608, // 8.0 MB
      pageCount: 440,
      publisher: 'Alta Books',
      publishedDate: '2009',
      isbn: '9780132350884',
    ),

    // 5. WATCHMEN (CBZ pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-watchmen-pt',
      title: 'Watchmen — Edição Definitiva',
      subtitle: 'Edição Definitiva',
      authors: ['Alan Moore', 'Dave Gibbons'],
      description:
          'Uma desconstrução revolucionária do mito dos super-heróis em uma realidade alternativa dos anos 80 à beira de uma guerra nuclear.',
      language: 'pt-BR',
      type: WorkType.comic,
      format: WorkFormat.cbz,
      coverUrl: 'mock://covers/watchmen.jpg',
      downloadUrl: 'mock://download/watchmen-pt.cbz',
      fileSizeBytes: 50331648, // 48 MB
      pageCount: 416,
      publisher: 'Panini Comics',
      publishedDate: '1986',
      isbn: '9788573516845',
    ),

    // 6. WATCHMEN (CBZ en) - Deduplicação HQ
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-watchmen-en',
      title: 'Watchmen',
      authors: ['Moore, Alan', 'Gibbons, Dave'],
      description:
          'A Hugo Award-winning graphic novel that chronicles the fall from grace of a group of superheroes plagued by all-too-human failings.',
      language: 'en',
      type: WorkType.comic,
      format: WorkFormat.cbz,
      coverUrl: 'mock://covers/watchmen-en.jpg',
      downloadUrl: 'mock://download/watchmen-en.cbz',
      fileSizeBytes: 54525952, // 52 MB
      pageCount: 416,
      publisher: 'DC Comics',
      publishedDate: '1986',
      isbn: '9788573516845',
    ),

    // 7. AKIRA (CBZ pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-akira-pt',
      title: 'Akira — Volume 1',
      subtitle: 'Volume 1',
      authors: ['Katsuhiro Otomo'],
      description:
          'Em uma Neo-Tokyo pós-apocalíptica de 2019 reconstruída sobre a antiga metrópole destruída pela Terceira Guerra Mundial, Kaneda e Tetsuo lideram uma gangue de motoqueiros.',
      language: 'pt-BR',
      type: WorkType.comic,
      format: WorkFormat.cbz,
      coverUrl: 'mock://covers/akira.jpg',
      downloadUrl: 'mock://download/akira.cbz',
      fileSizeBytes: 68157440, // 65 MB
      pageCount: 360,
      publisher: 'Editora JBC',
      publishedDate: '1982',
      series: 'Akira',
      volume: '1',
    ),

    // 8. NEUROMANCER (EPUB pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-neuromancer-pt',
      title: 'Neuromancer: Trilogia do Sprawl',
      subtitle: 'Trilogia do Sprawl',
      authors: ['William Gibson'],
      description:
          'O romance seminal do movimento cyberpunk. Case é um ex-hacker e cowboy do ciberespaço que teve seu sistema nervoso danificado como punição.',
      language: 'pt-BR',
      type: WorkType.book,
      format: WorkFormat.epub,
      coverUrl: 'mock://covers/neuromancer.jpg',
      downloadUrl: 'mock://download/neuromancer.epub',
      fileSizeBytes: 2936012, // 2.8 MB
      pageCount: 320,
      publisher: 'Editora Aleph',
      publishedDate: '1984',
      isbn: '9788576570028',
      series: 'Trilogia do Sprawl',
      volume: '1',
    ),

    // 9. FUNDAÇÃO (EPUB pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-fundacao-pt',
      title: 'Fundação: Ciclo da Fundação',
      subtitle: 'Ciclo da Fundação',
      authors: ['Isaac Asimov'],
      description:
          'O Império Galáctico está à beira do colapso. O matemático Hari Seldon cria a psico-história para abreviar a idade das trevas iminente.',
      language: 'pt-BR',
      type: WorkType.book,
      format: WorkFormat.epub,
      coverUrl: 'mock://covers/fundacao.jpg',
      downloadUrl: 'mock://download/fundacao.epub',
      fileSizeBytes: 2306867, // 2.2 MB
      pageCount: 240,
      publisher: 'Editora Aleph',
      publishedDate: '1951',
      isbn: '9788576570677',
      series: 'Ciclo da Fundação',
      volume: '1',
    ),

    // 10. DOM CASMURRO (TXT pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-domcasmurro-pt',
      title: 'Dom Casmurro',
      authors: ['Machado de Assis'],
      description:
          'Obra clássica do Realismo brasileiro onde Bento Santiago narra suas memórias e sua obsessão ciumenta por Capitu de olhos de ressaca.',
      language: 'pt-BR',
      type: WorkType.book,
      format: WorkFormat.txt,
      coverUrl: 'mock://covers/domcasmurro.jpg',
      downloadUrl: 'mock://download/domcasmurro.txt',
      fileSizeBytes: 524288, // 512 KB
      pageCount: 256,
      publisher: 'Domínio Público',
      publishedDate: '1899',
    ),

    // 11. OS VINGADORES (CBZ pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-vingadores-pt',
      title: 'Os Vingadores: A Queda',
      subtitle: 'Edição Especial',
      authors: ['Brian Michael Bendis', 'David Finch'],
      description:
          'O pior dia na história dos Heróis Mais Poderosos da Terra. Uma tragédia sem precedentes atinge a Mansão dos Vingadores.',
      language: 'pt-BR',
      type: WorkType.comic,
      format: WorkFormat.cbz,
      coverUrl: 'https://covers.openlibrary.org/b/id/11711194-M.jpg',
      downloadUrl: 'mock://download/vingadores-pt.cbz',
      fileSizeBytes: 48000000,
      pageCount: 176,
      publisher: 'Marvel Comics / Panini',
      publishedDate: '2004',
      series: 'Os Vingadores',
      volume: '1',
    ),

    // 12. HOMEM-ARANHA (CBZ pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-homemaranha-pt',
      title: 'Homem-Aranha: A Última Caçada de Kraven',
      authors: ['J.M. DeMatteis', 'Mike Zeck'],
      description:
          'A mais sombria e aclamada história do Homem-Aranha. Kraven, o Caçador, enterra Peter Parker vivo e assume seu manto pelas ruas de Nova York.',
      language: 'pt-BR',
      type: WorkType.comic,
      format: WorkFormat.cbz,
      coverUrl: 'https://covers.openlibrary.org/b/id/10521404-M.jpg',
      downloadUrl: 'mock://download/homemaranha-pt.cbz',
      fileSizeBytes: 52000000,
      pageCount: 168,
      publisher: 'Marvel Comics / Panini',
      publishedDate: '1987',
      series: 'Homem-Aranha',
    ),

    // 13. 1984 (EPUB pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-1984-pt',
      title: '1984',
      authors: ['George Orwell'],
      description:
          'O Grande Irmão está de olho em você. Em uma Londres distópica vigiada por teletelas, Winston Smith trabalha no Ministério da Verdade reescrevendo o passado.',
      language: 'pt-BR',
      type: WorkType.book,
      format: WorkFormat.epub,
      coverUrl: 'https://covers.openlibrary.org/b/id/8575742-M.jpg',
      downloadUrl: 'mock://download/1984-pt.epub',
      fileSizeBytes: 2097152,
      pageCount: 336,
      publisher: 'Companhia das Letras',
      publishedDate: '1949',
      isbn: '9788535914849',
    ),

    // 14. O SENHOR DOS ANÉIS (EPUB pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-senhordosaneis-pt',
      title: 'O Senhor dos Anéis: A Sociedade do Anel',
      authors: ['J.R.R. Tolkien'],
      description:
          'Nas profundezas da Terra-média, o jovem hobbit Frodo Bolseiro recebe a terrível missão de levar o Um Anel de Sauron até as chamas da Montanha da Perdição.',
      language: 'pt-BR',
      type: WorkType.book,
      format: WorkFormat.epub,
      coverUrl: 'https://covers.openlibrary.org/b/id/8231856-M.jpg',
      downloadUrl: 'mock://download/senhordosaneis-pt.epub',
      fileSizeBytes: 4194304,
      pageCount: 576,
      publisher: 'HarperCollins',
      publishedDate: '1954',
      series: 'O Senhor dos Anéis',
      volume: '1',
      isbn: '9788595084759',
    ),

    // 15. HARRY POTTER (EPUB pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-harrypotter-pt',
      title: 'Harry Potter e a Pedra Filosofal',
      authors: ['J.K. Rowling'],
      description:
          'O garoto órfão Harry Potter descobre em seu décimo primeiro aniversário que é um bruxo e é convidado a ingressar na Escola de Magia e Bruxaria de Hogwarts.',
      language: 'pt-BR',
      type: WorkType.book,
      format: WorkFormat.epub,
      coverUrl: 'https://covers.openlibrary.org/b/id/10521270-M.jpg',
      downloadUrl: 'mock://download/harrypotter-pt.epub',
      fileSizeBytes: 3145728,
      pageCount: 224,
      publisher: 'Editora Rocco',
      publishedDate: '1997',
      series: 'Harry Potter',
      volume: '1',
      isbn: '9788532511010',
    ),

    // 16. BATMAN: O CAVALEIRO DAS TREVAS (CBZ pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-batman-pt',
      title: 'Batman: O Cavaleiro das Trevas',
      subtitle: 'Edição Definitiva',
      authors: ['Frank Miller', 'Klaus Janson', 'Lynn Varley'],
      description:
          'Um Batman envelhecido retorna da aposentadoria para livrar Gotham City do crime e da corrupção.',
      language: 'pt-BR',
      type: WorkType.comic,
      format: WorkFormat.cbz,
      coverUrl: 'https://covers.openlibrary.org/b/id/8231991-M.jpg',
      downloadUrl: 'mock://download/batman-pt.cbz',
      fileSizeBytes: 65000000,
      pageCount: 200,
      publisher: 'DC Comics / Panini',
      publishedDate: '1986',
      series: 'Batman',
      volume: '1',
    ),

    // 17. BATMAN: YEAR ONE (CBZ en)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-batman-en',
      title: 'Batman: Year One',
      authors: ['Frank Miller', 'David Mazzucchelli'],
      description:
          'The definitive origin story of Bruce Wayne becoming Batman and Jim Gordon fighting police corruption.',
      language: 'en',
      type: WorkType.comic,
      format: WorkFormat.cbz,
      coverUrl: 'https://covers.openlibrary.org/b/id/8231992-M.jpg',
      downloadUrl: 'mock://download/batman-en.cbz',
      fileSizeBytes: 45000000,
      pageCount: 144,
      publisher: 'DC Comics',
      publishedDate: '1987',
      series: 'Batman',
    ),

    // 18. THE AVENGERS (CBZ en)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-avengers-en',
      title: 'The Avengers: Earth\'s Mightiest Heroes',
      authors: ['Stan Lee', 'Jack Kirby'],
      description:
          'And there came a day, a day unlike any other, when Earth\'s mightiest heroes found themselves united against a common threat.',
      language: 'en',
      type: WorkType.comic,
      format: WorkFormat.cbz,
      coverUrl: 'https://covers.openlibrary.org/b/id/11711194-M.jpg',
      downloadUrl: 'mock://download/avengers-en.cbz',
      fileSizeBytes: 42000000,
      pageCount: 150,
      publisher: 'Marvel Comics',
      publishedDate: '1963',
      series: 'The Avengers',
    ),

    // 19. SPIDER-MAN (CBZ en)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-spiderman-en',
      title: 'Spider-Man: Blue',
      authors: ['Jeph Loeb', 'Tim Sale'],
      description:
          'Peter Parker reflects on his first true love, Gwen Stacy, and the heartbreaking loss that changed him forever.',
      language: 'en',
      type: WorkType.comic,
      format: WorkFormat.cbz,
      coverUrl: 'https://covers.openlibrary.org/b/id/10521404-M.jpg',
      downloadUrl: 'mock://download/spiderman-en.cbz',
      fileSizeBytes: 48000000,
      pageCount: 160,
      publisher: 'Marvel Comics',
      publishedDate: '2002',
      series: 'Spider-Man',
    ),

    // 20. PAI RICO, PAI POBRE (EPUB pt-BR)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-pairico-pt',
      title: 'Pai Rico, Pai Pobre',
      subtitle: 'O que os ricos ensinam a seus filhos sobre dinheiro',
      authors: ['Robert T. Kiyosaki', 'Sharon L. Lechter'],
      description:
          'Aprenda como a educação financeira pode mudar a sua visão sobre investimentos, ativos e passivos.',
      language: 'pt-BR',
      type: WorkType.book,
      format: WorkFormat.epub,
      coverUrl: 'https://covers.openlibrary.org/b/id/8315124-M.jpg',
      downloadUrl: 'mock://download/pairico-pt.epub',
      fileSizeBytes: 2097152,
      pageCount: 336,
      publisher: 'Editora Alta Books',
      publishedDate: '1997',
      isbn: '9788576089483',
    ),

    // 21. RICH DAD POOR DAD (EPUB en)
    const ExternalWorkMetadata(
      providerId: 'mock-content-provider',
      externalId: 'mock-richdad-en',
      title: 'Rich Dad Poor Dad',
      subtitle:
          'What the Rich Teach Their Kids About Money That the Poor and Middle Class Do Not!',
      authors: ['Robert T. Kiyosaki'],
      description:
          'The number 1 personal finance book of all time. It tells the story of Robert Kiyosaki and his two dads.',
      language: 'en',
      type: WorkType.book,
      format: WorkFormat.epub,
      coverUrl: 'https://covers.openlibrary.org/b/id/8315125-M.jpg',
      downloadUrl: 'mock://download/richdad-en.epub',
      fileSizeBytes: 2500000,
      pageCount: 336,
      publisher: 'Plata Publishing',
      publishedDate: '1997',
      isbn: '9788576089483',
    ),
  ];

  @override
  Future<ProviderHealth> checkHealth() async {
    if (simulatedLatency > Duration.zero) {
      await Future.delayed(simulatedLatency);
    }
    if (simulateError) {
      return ProviderHealth.offline(
        message: 'Simulação de erro em MockContentProvider',
      );
    }
    if (forcedStatus != ProviderStatus.healthy) {
      return ProviderHealth(
        status: forcedStatus,
        lastChecked: DateTime.now(),
        errorMessage: 'Status forçado para teste',
      );
    }
    return ProviderHealth.healthy(latencyMs: simulatedLatency.inMilliseconds);
  }

  @override
  Future<List<ExternalWorkMetadata>> search(
    String query, {
    WorkType? type,
    String? language,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (simulatedLatency > Duration.zero) {
      await Future.delayed(simulatedLatency);
    }

    if (simulateTimeout) {
      // Simula uma espera maior que o timeout
      await Future.delayed(timeout + const Duration(seconds: 2));
      throw TimeoutException('Simulação de timeout no MockContentProvider');
    }

    if (simulateError) {
      throw NovaException(
        kind: NovaErrorKind.providerError,
        message: 'Falha simulada no MockContentProvider para busca "$query"',
      );
    }

    final normQuery = MetadataNormalizer.normalizeSearchTerm(query);

    var results = _mockCatalog.where((item) {
      // Filtro de tipo
      if (type != null && item.type != type) return false;

      // Filtro de idioma
      if (language != null &&
          item.language?.toLowerCase() != language.toLowerCase()) {
        return false;
      }

      // Se query vazia ou asterisco, retorna tudo
      if (normQuery.isEmpty || query.trim() == '*') return true;

      // Correspondência normalizada tolerante a acentos e hífens
      final normTitle = MetadataNormalizer.normalizeSearchTerm(item.title);
      final normDesc = item.description != null
          ? MetadataNormalizer.normalizeSearchTerm(item.description!)
          : '';
      final normSeries = item.series != null
          ? MetadataNormalizer.normalizeSearchTerm(item.series!)
          : '';
      final authorMatch = item.authors.any(
        (a) => MetadataNormalizer.normalizeSearchTerm(a).contains(normQuery),
      );

      final titleMatch = normTitle.contains(normQuery);
      final seriesMatch = normSeries.contains(normQuery);
      final descMatch = normDesc.contains(normQuery);

      // Multi-word matching
      final words = normQuery.split(' ').where((w) => w.isNotEmpty).toList();
      final wordsInTitle =
          words.isNotEmpty && words.every((w) => normTitle.contains(w));
      final wordsInAuthorOrTitle =
          words.isNotEmpty &&
          words.every(
            (w) =>
                normTitle.contains(w) ||
                item.authors.any(
                  (a) => MetadataNormalizer.normalizeSearchTerm(a).contains(w),
                ),
          );

      return titleMatch ||
          authorMatch ||
          seriesMatch ||
          descMatch ||
          wordsInTitle ||
          wordsInAuthorOrTitle;
    }).toList();

    // Paginação
    final startIndex = (page - 1) * pageSize;
    if (startIndex >= results.length) return [];

    final endIndex = (startIndex + pageSize) > results.length
        ? results.length
        : startIndex + pageSize;

    return results.sublist(startIndex, endIndex);
  }

  @override
  Future<ExternalWorkMetadata?> getDetails(String externalId) async {
    if (simulatedLatency > Duration.zero) {
      await Future.delayed(simulatedLatency);
    }

    if (simulateError) {
      throw NovaException(
        kind: NovaErrorKind.providerError,
        message: 'Falha simulada em getDetails("$externalId")',
      );
    }

    final matches = _mockCatalog.where((item) => item.externalId == externalId);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Future<String?> resolveDownloadUrl(
    String externalId,
    WorkFormat format,
  ) async {
    if (simulatedLatency > Duration.zero) {
      await Future.delayed(simulatedLatency);
    }

    final details = await getDetails(externalId);
    if (details != null) {
      if (details.format == format) {
        return details.downloadUrl;
      }
      return null;
    }
    // Fallback gracioso para qualquer edição do catálogo mock
    return 'mock://download/$externalId.${format.extension}';
  }
}
