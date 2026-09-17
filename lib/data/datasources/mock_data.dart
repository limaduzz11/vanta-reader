import '../../domain/entities/work.dart';
import '../../domain/entities/reading_progress.dart';
import '../../domain/entities/download_item.dart';

/// Catálogo de Dados Simulados (Mock) — TEST ONLY.
///
/// NUNCA é carregado no runtime normal de produção. O composition root
/// (injection.dart) só registra mocks sob configuração de teste explícita.
/// Fixtures de capa: `test/fixtures/covers/` (fora do bundle release).
class MockData {
  MockData._();

  static final List<Work> allWorks = [
    // 1. DUNA (Livro)
    Work(
      id: 'work-dune',
      workKey: 'duna_frank_herbert',
      title: 'Duna',
      subtitle: 'Crônicas de Duna — Livro 1',
      author: 'Frank Herbert',
      description:
          'Uma obra-prima da ficção científica que se passa no inóspito planeta desértico Arrakis, a única fonte da substância mais valiosa do universo: o mélange. O jovem Paul Atreides deve liderar os Fremen em uma batalha épica pelo controle do planeta e seu destino messiânico.',
      primaryLanguage: 'pt-BR',
      type: WorkType.book,
      series: 'Crônicas de Duna',
      volume: '1',
      publisher: 'Editora Aleph',
      publishedDate: '1965',
      isbn: '9788576573135',
      coverPath: 'test/fixtures/covers/duna.jpeg',
      editions: const [
        WorkEdition(
          id: 'ed-dune-epub',
          workId: 'work-dune',
          format: WorkFormat.epub,
          fileSize: 3145728, // 3 MB
          pageCount: 680,
          downloadUrl: 'mock://download/dune-epub',
          providerId: 'mock-content-provider',
          isLocal: true,
        ),
        WorkEdition(
          id: 'ed-dune-pdf',
          workId: 'work-dune',
          format: WorkFormat.pdf,
          fileSize: 12582912, // 12 MB
          pageCount: 680,
          downloadUrl: 'mock://download/dune-pdf',
          providerId: 'mock-content-provider',
          isLocal: false,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    ),

    // 2. CLEAN CODE (Livro)
    Work(
      id: 'work-cleancode',
      workKey: 'clean_code_robert_martin',
      title: 'Clean Code',
      subtitle: 'A Handbook of Agile Software Craftsmanship',
      author: 'Robert C. Martin',
      description:
          'Even bad code can function. But if code isn\'t clean, it can bring a development organization to its knees. Every year, countless hours and significant resources are lost due to poorly written code. This book will teach you how to write good code and make it better.',
      primaryLanguage: 'en',
      type: WorkType.book,
      series: 'Robert C. Martin Series',
      publisher: 'Prentice Hall',
      publishedDate: '2008',
      isbn: '9780132350884',
      coverPath: 'test/fixtures/covers/clean_code.jpeg',
      editions: const [
        WorkEdition(
          id: 'ed-cleancode-epub',
          workId: 'work-cleancode',
          format: WorkFormat.epub,
          fileSize: 5242880, // 5 MB
          pageCount: 464,
          downloadUrl: 'mock://download/cleancode-epub',
          providerId: 'mock-content-provider',
          isLocal: true,
        ),
        WorkEdition(
          id: 'ed-cleancode-pdf',
          workId: 'work-cleancode',
          format: WorkFormat.pdf,
          fileSize: 15728640,
          pageCount: 464,
          downloadUrl: 'mock://download/cleancode-pdf',
          providerId: 'mock-content-provider',
          isLocal: false,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),

    // 3. BATMAN: ANO UM (HQ)
    Work(
      id: 'work-batman-y1',
      workKey: 'batman_year_one_miller',
      title: 'Batman: Ano Um',
      subtitle: 'Edição Definitiva',
      author: 'Frank Miller & David Mazzucchelli',
      description:
          'Em 1986, Frank Miller e David Mazzucchelli produziram esta obra seminal que reinventou as origens do Cavaleiro das Trevas. Gotham City está apodrecida pela corrupção, e o jovem tenente Jim Gordon e o bilionário Bruce Wayne iniciam suas cruzadas paralelas por justiça.',
      primaryLanguage: 'pt-BR',
      type: WorkType.comic,
      series: 'Batman',
      volume: 'Ano Um',
      publisher: 'DC Comics / Panini',
      publishedDate: '1987',
      coverPath: 'test/fixtures/covers/batman_ano_um.jpeg',
      editions: const [
        WorkEdition(
          id: 'ed-batman-cbz',
          workId: 'work-batman-y1',
          format: WorkFormat.cbz,
          fileSize: 146800640, // 140 MB
          pageCount: 144,
          downloadUrl: 'mock://download/batman-cbz',
          providerId: 'mock-content-provider',
          isLocal: true,
        ),
        WorkEdition(
          id: 'ed-batman-cbr',
          workId: 'work-batman-y1',
          format: WorkFormat.cbr,
          fileSize: 136314880,
          pageCount: 144,
          downloadUrl: 'mock://download/batman-cbr',
          providerId: 'mock-content-provider',
          isLocal: false,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),

    // 4. WATCHMEN (HQ)
    Work(
      id: 'work-watchmen',
      workKey: 'watchmen_alan_moore',
      title: 'Watchmen',
      subtitle: 'Edição Histórica',
      author: 'Alan Moore & Dave Gibbons',
      description:
          'Um mistério policial que se desdobra em uma conspiração de proporções globais. Em uma América distópica de 1985 durante a Guerra Fria, a morte de um super-herói aposentado dispara uma investigação que questiona a própria moralidade humana: Quem vigia os vigilantes?',
      primaryLanguage: 'pt-BR',
      type: WorkType.comic,
      series: 'Watchmen',
      publisher: 'DC Comics / Panini',
      publishedDate: '1986',
      isbn: '9788573515435',
      coverPath: 'test/fixtures/covers/watchmen.jpeg',
      editions: const [
        WorkEdition(
          id: 'ed-watchmen-cbz',
          workId: 'work-watchmen',
          format: WorkFormat.cbz,
          fileSize: 314572800, // 300 MB
          pageCount: 416,
          downloadUrl: 'mock://download/watchmen-cbz',
          providerId: 'mock-content-provider',
          isLocal: true,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    ),

    // 5. NEUROMANCER (Livro)
    Work(
      id: 'work-neuromancer',
      workKey: 'neuromancer_william_gibson',
      title: 'Neuromancer',
      subtitle: 'Trilogia do Sprawl — Livro 1',
      author: 'William Gibson',
      description:
          'O romance que fundou o gênero Cyberpunk e cunhou o termo ciberespaço. Case é um ex-hacker e cowboy do console cujo sistema nervoso foi queimado por toxinas russas após trair seus chefes. Uma nova chance surge ao lado de Molly Millions para invadir uma poderosa IA corporativa.',
      primaryLanguage: 'pt-BR',
      type: WorkType.book,
      series: 'Trilogia do Sprawl',
      volume: '1',
      publisher: 'Editora Aleph',
      publishedDate: '1984',
      isbn: '9788576573005',
      coverPath: 'test/fixtures/covers/neuromancer.jpeg',
      editions: const [
        WorkEdition(
          id: 'ed-neuro-epub',
          workId: 'work-neuromancer',
          format: WorkFormat.epub,
          fileSize: 2097152, // 2 MB
          pageCount: 320,
          downloadUrl: 'mock://download/neuro-epub',
          providerId: 'mock-content-provider',
          isLocal: false,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
      updatedAt: DateTime.now().subtract(const Duration(days: 8)),
    ),

    // 6. SANDMAN: PRELÚDIOS E NOTURNOS (HQ)
    Work(
      id: 'work-sandman-1',
      workKey: 'sandman_preludios_gaiman',
      title: 'Sandman: Prelúdios & Noturnos',
      subtitle: 'Volume 1',
      author: 'Neil Gaiman',
      description:
          'Morpheus, o Senhor dos Sonhos, é capturado e mantido em cativeiro por ocultistas humanos durante sete décadas. Ao finalmente se libertar na virada do século XXI, ele deve recuperar seus três símbolos de poder: a algibeira de areia, seu elmo de osso e o rubi dos sonhos.',
      primaryLanguage: 'pt-BR',
      type: WorkType.comic,
      series: 'The Sandman',
      volume: '1',
      publisher: 'Vertigo / Panini',
      publishedDate: '1989',
      coverPath: 'test/fixtures/covers/sandman.jpeg',
      editions: const [
        WorkEdition(
          id: 'ed-sandman-cbz',
          workId: 'work-sandman-1',
          format: WorkFormat.cbz,
          fileSize: 220200960, // 210 MB
          pageCount: 240,
          downloadUrl: 'mock://download/sandman-cbz',
          providerId: 'mock-content-provider',
          isLocal: true,
        ),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
  ];

  static final List<ReadingProgress> sampleProgressList = [
    ReadingProgress(
      workId: 'work-dune',
      editionId: 'ed-dune-epub',
      chapterId: 'Capítulo 4 — A Chegada em Arrakis',
      currentPage: 142,
      totalPages: 680,
      percentage: 0.208,
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    ReadingProgress(
      workId: 'work-batman-y1',
      editionId: 'ed-batman-cbz',
      chapterId: 'Parte 2 — Gotham em Chamas',
      currentPage: 64,
      totalPages: 144,
      percentage: 0.444,
      updatedAt: DateTime.now().subtract(const Duration(minutes: 35)),
    ),
  ];

  static final List<DownloadItem> sampleDownloads = [
    DownloadItem(
      id: 'dl-sandman',
      workId: 'work-sandman-1',
      editionId: 'ed-sandman-cbz',
      title: 'Sandman: Prelúdios & Noturnos',
      targetPath: '/VANTAReader/comics/sandman_vol1.cbz',
      downloadUrl: 'mock://download/sandman-cbz',
      totalBytes: 220200960,
      downloadedBytes: 220200960,
      status: DownloadStatus.completed,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    DownloadItem(
      id: 'dl-neuromancer',
      workId: 'work-neuromancer',
      editionId: 'ed-neuro-epub',
      title: 'Neuromancer (Gibson)',
      targetPath: '/VANTAReader/books/neuromancer.epub',
      downloadUrl: 'mock://download/neuro-epub',
      totalBytes: 2097152,
      downloadedBytes: 1363148, // 65%
      status: DownloadStatus.downloading,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      updatedAt: DateTime.now().subtract(const Duration(seconds: 10)),
    ),
  ];
}
