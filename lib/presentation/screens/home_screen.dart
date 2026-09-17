import 'package:flutter/material.dart';
import '../../core/providers/work_identity_system.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_dimensions.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';
import '../../data/datasources/providers/internet_archive_content_provider.dart';
import '../../data/datasources/providers/open_library_content_provider.dart';
import '../../domain/entities/work.dart';
import '../../domain/repositories/i_library_repository.dart';
import '../../injection.dart';
import '../design_system/nova_book_card.dart';
import '../design_system/nova_card.dart';
import '../design_system/nova_comic_card.dart';
import '../design_system/nova_cover_image.dart';
import '../design_system/nova_states.dart';
import 'work_details_screen.dart';

/// Tela Inicial — Home do VANTA Reader
///
/// R3e: dados REAIS e honestos.
/// - Livros populares: Open Library (metadata/capas reais).
/// - Quadrinhos em destaque: Internet Archive (comics public domain, com
///   verificação por item).
/// - Continuar lendo: progresso REAL do usuário (nunca fixo/mock).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Work> _popularBooks = [];
  List<Work> _featuredComics = [];
  Work? _continueReadingWork;
  String? _continueReadingEditionId;
  double _continueReadingProgress = 0.0;
  bool _isLoadingApi = false;

  @override
  void initState() {
    super.initState();
    _loadApiContent();
  }

  Future<void> _loadApiContent() async {
    setState(() => _isLoadingApi = true);
    await Future.wait([
      _loadPopularBooks(),
      _loadFeaturedComics(),
      _loadContinueReading(),
    ]);
    if (mounted) {
      setState(() => _isLoadingApi = false);
    }
  }

  Future<void> _loadPopularBooks() async {
    if (!getIt.isRegistered<OpenLibraryContentProvider>()) return;
    try {
      final provider = getIt<OpenLibraryContentProvider>();
      final trendingRaw = await provider.getTrendingBooks(limit: 12);
      if (trendingRaw.isNotEmpty) {
        final mergedBooks = WorkIdentitySystem.deduplicateAndMerge(trendingRaw);
        if (mergedBooks.isNotEmpty && mounted) {
          setState(() {
            _popularBooks = mergedBooks;
          });
        }
      }
    } catch (_) {
      // Silencioso: a UI exibe estado vazio honesto.
    }
  }

  Future<void> _loadFeaturedComics() async {
    if (!getIt.isRegistered<InternetArchiveContentProvider>()) return;
    try {
      final provider = getIt<InternetArchiveContentProvider>();
      final comicsRaw = await provider.getFeaturedComics(limit: 10);
      if (comicsRaw.isNotEmpty) {
        final mergedComics = WorkIdentitySystem.deduplicateAndMerge(comicsRaw);
        if (mergedComics.isNotEmpty && mounted) {
          setState(() {
            _featuredComics = mergedComics;
          });
        }
      }
    } catch (_) {
      // Silencioso: a UI exibe estado vazio honesto.
    }
  }

  /// CONTINUAR LENDO: a partir do progresso REAL persistido no SQLite.
  /// Nunca usa obra/progresso fixo. Sem progresso → seção oculta.
  Future<void> _loadContinueReading() async {
    try {
      final repo = getIt<ILibraryRepository>();
      final works = await repo.getLibraryWorks();
      Work? bestWork;
      String? bestEditionId;
      double bestProgress = 0.0;

      for (final work in works) {
        final progress = await repo.getProgress(work.id);
        if (progress != null &&
            progress.percentage > 0.0 &&
            progress.percentage < 0.999) {
          if (progress.percentage > bestProgress) {
            bestProgress = progress.percentage;
            bestWork = work;
            bestEditionId = progress.editionId;
          }
        }
      }

      if (mounted) {
        setState(() {
          _continueReadingWork = bestWork;
          _continueReadingEditionId = bestEditionId;
          _continueReadingProgress = bestProgress;
        });
      }
    } catch (_) {
      // Sem progresso real → sem card.
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = _popularBooks;
    final comics = _featuredComics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('VANTA Reader'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: NovaColors.textSecondary,
            ),
            tooltip: 'Sobre o VANTA Reader',
            onPressed: () {
              showAboutDialog(
                context: context,
                applicationName: 'VANTA Reader',
                applicationVersion: '1.0.0 (VANTA Labz)',
                applicationLegalese:
                    'Desenvolvido por VANTA Labz • Leitura local-first com fontes de domínio público e APIs abertas • Minimalismo monocromático',
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadApiContent,
        color: NovaColors.accent,
        backgroundColor: NovaColors.surfaceSecondary,
        child: ListView(
          padding: NovaSpacing.pagePadding,
          children: [
            // 1. CONTINUAR LENDO (só com progresso real)
            if (_continueReadingWork != null) ...[
              Text('CONTINUAR LENDO', style: NovaTypography.caption),
              const SizedBox(height: NovaSpacing.sm),
              _buildContinueReadingCard(context),
              const SizedBox(height: NovaSpacing.xl),
            ],

            // 2. LIVROS POPULARES
            _buildSectionHeader(
              'LIVROS POPULARES',
              'Ver todos',
              isLoading: _isLoadingApi,
            ),
            const SizedBox(height: NovaSpacing.sm),
            if (books.isEmpty)
              _buildEmptySection(
                'Sem livros no momento. Tente novamente mais tarde.',
              )
            else
              SizedBox(
                height: NovaDimensions.homeCarouselHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: books.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: NovaSpacing.md),
                  itemBuilder: (context, index) {
                    final book = books[index];
                    return NovaBookCard(
                      work: book,
                      width: 135.0,
                      onTap: () => _openDetails(context, book),
                    );
                  },
                ),
              ),

            const SizedBox(height: NovaSpacing.xl),

            // 3. QUADRINHOS EM DESTAQUE (fonte comic real — Internet Archive PD)
            _buildSectionHeader('QUADRINHOS EM DESTAQUE', 'Ver todos'),
            const SizedBox(height: NovaSpacing.sm),
            if (comics.isEmpty)
              _buildEmptySection(
                'Nenhuma HQ disponível agora. Pesquise na aba de busca.',
              )
            else
              SizedBox(
                height: NovaDimensions.homeComicCarouselHeight,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: comics.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: NovaSpacing.md),
                  itemBuilder: (context, index) {
                    final comic = comics[index];
                    return NovaComicCard(
                      work: comic,
                      width: 145.0,
                      onTap: () => _openDetails(context, comic),
                    );
                  },
                ),
              ),

            const SizedBox(height: NovaSpacing.xl),

            // 4. BANNER LOCAL-FIRST
            NovaCard(
              padding: NovaSpacing.cardPadding,
              backgroundColor: NovaColors.surfaceSecondary,
              child: Row(
                children: [
                  const Icon(
                    Icons.offline_pin_outlined,
                    size: 28,
                    color: NovaColors.accent,
                  ),
                  const SizedBox(width: NovaSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biblioteca 100% Offline',
                          style: NovaTypography.titleMedium,
                        ),
                        const SizedBox(height: NovaSpacing.xxs),
                        Text(
                          'Apenas o conteúdo que você baixou fica disponível offline. Metadata não é conteúdo.',
                          style: NovaTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NovaSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueReadingCard(BuildContext context) {
    final work = _continueReadingWork!;
    final progress = _continueReadingProgress;

    return NovaCard(
      padding: NovaSpacing.cardPadding,
      onTap: () =>
          _openDetails(context, work, editionId: _continueReadingEditionId),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 84,
            decoration: BoxDecoration(
              color: NovaColors.surfaceSecondary,
              borderRadius: NovaShapes.roundedSm,
              border: Border.all(color: NovaColors.border),
            ),
            child: ClipRRect(
              borderRadius: NovaShapes.roundedSm,
              child: NovaCoverImage(
                work: work,
                width: 58,
                height: 84,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: NovaSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        work.title,
                        style: NovaTypography.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: NovaTypography.labelMedium.copyWith(
                        color: NovaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: NovaSpacing.xxs),
                Text(
                  'Retome de onde parou',
                  style: NovaTypography.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: NovaSpacing.sm),
                NovaProgressBar(progress: progress, height: 4.0),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    String title,
    String actionLabel, {
    bool isLoading = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(title, style: NovaTypography.caption),
            if (isLoading) ...[
              const SizedBox(width: NovaSpacing.xs),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(NovaColors.accent),
                ),
              ),
            ],
          ],
        ),
        Text(
          actionLabel,
          style: NovaTypography.caption.copyWith(color: NovaColors.accentLight),
        ),
      ],
    );
  }

  Widget _buildEmptySection(String message) {
    return NovaCard(
      padding: const EdgeInsets.all(NovaSpacing.md),
      backgroundColor: NovaColors.surfaceSecondary.withValues(alpha: 0.4),
      child: Center(
        child: Text(
          message,
          style: NovaTypography.bodySmall.copyWith(color: NovaColors.textMuted),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, Work work, {String? editionId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkDetailsScreen(work: work, editionId: editionId),
      ),
    );
  }
}
