import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/services/file_picker_service.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_dimensions.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_typography.dart';
import '../../domain/entities/work.dart';
import '../../injection.dart';
import '../blocs/library/library_bloc.dart';
import '../blocs/library/library_event.dart';
import '../blocs/library/library_state.dart';
import 'package:go_router/go_router.dart';
import '../design_system/nova_book_card.dart';
import '../design_system/nova_button.dart';
import '../design_system/nova_card.dart';
import '../design_system/nova_comic_card.dart';
import '../design_system/nova_states.dart';
import 'work_details_screen.dart';

/// Tela da Biblioteca Local — Conectada ao SQLite via LibraryBloc (Fase D)
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryBloc>(
      create: (_) => getIt<LibraryBloc>()..add(const LoadLibraryEvent()),
      child: const _LibraryView(),
    );
  }
}

class _LibraryView extends StatefulWidget {
  const _LibraryView();

  @override
  State<_LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<_LibraryView> {
  bool _isGridView = true;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LibraryBloc, LibraryState>(
      listener: (context, state) {
        if (state is LibraryLoaded && state.lastImportedTitle != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: NovaColors.surfaceSecondary,
              content: Text(
                'Obra "${state.lastImportedTitle}" importada com sucesso!',
                style: NovaTypography.bodyMedium.copyWith(
                  color: NovaColors.textPrimary,
                ),
              ),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: NovaShapes.roundedSm,
                side: const BorderSide(color: NovaColors.border),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is LibraryLoading || state is LibraryInitial) {
          return Scaffold(
            appBar: AppBar(title: const Text('Biblioteca')),
            body: const Center(
              child: NovaLoadingState(
                message: 'Carregando biblioteca local...',
              ),
            ),
          );
        }

        if (state is LibraryError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Biblioteca')),
            body: Center(
              child: NovaErrorState(
                message: state.message,
                onRetry: () =>
                    context.read<LibraryBloc>().add(const LoadLibraryEvent()),
              ),
            ),
          );
        }

        final loaded = state as LibraryLoaded;
        final all = loaded.works;
        final books = all.where((w) => w.type == WorkType.book).toList();
        final comics = all.where((w) => w.type == WorkType.comic).toList();
        final favorites = all.where((w) => loaded.isFavorite(w.id)).toList();
        final downloaded = all.where((w) => w.isDownloaded).toList();

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Biblioteca'),
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.file_upload_outlined,
                    color: NovaColors.textSecondary,
                  ),
                  tooltip: 'Importar Arquivo Local',
                  onPressed: () => _importWork(context),
                ),
                IconButton(
                  icon: Icon(
                    _isGridView
                        ? Icons.view_list_rounded
                        : Icons.grid_view_rounded,
                    color: NovaColors.textSecondary,
                  ),
                  tooltip: _isGridView
                      ? 'Visualizar em Lista'
                      : 'Visualizar em Grade',
                  onPressed: () {
                    setState(() {
                      _isGridView = !_isGridView;
                    });
                  },
                ),
              ],
              bottom: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: NovaTypography.labelMedium,
                unselectedLabelStyle: NovaTypography.bodySmall,
                tabs: [
                  Tab(text: 'Todos (${all.length})'),
                  Tab(text: 'Livros (${books.length})'),
                  Tab(text: 'Quadrinhos (${comics.length})'),
                  Tab(text: 'Favoritos (${favorites.length})'),
                  Tab(text: 'Baixados (${downloaded.length})'),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: NovaColors.surfaceSecondary,
              foregroundColor: NovaColors.textPrimary,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: NovaShapes.roundedSm,
                side: const BorderSide(color: NovaColors.border),
              ),
              icon: const Icon(
                Icons.file_upload_outlined,
                size: 20,
                color: NovaColors.accent,
              ),
              label: Text('Importar', style: NovaTypography.labelMedium),
              onPressed: () => _importWork(context),
            ),
            body: TabBarView(
              children: [
                _buildWorksView(all, loaded),
                _buildWorksView(books, loaded),
                _buildWorksView(comics, loaded),
                _buildWorksView(favorites, loaded),
                _buildWorksView(downloaded, loaded),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWorksView(List<Work> works, LibraryLoaded state) {
    if (works.isEmpty) {
      return Padding(
        padding: NovaSpacing.pagePadding,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const NovaEmptyState(
                icon: Icons.local_library_outlined,
                title: 'Nenhuma obra adicionada ainda',
                description:
                    'Explore o acervo mundial pela Busca, baixe obras para ler offline ou importe arquivos do seu dispositivo.',
              ),
              const SizedBox(height: NovaSpacing.lg),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: NovaSpacing.sm,
                runSpacing: NovaSpacing.sm,
                children: [
                  NovaButton(
                    text: 'BUSCAR OBRAS',
                    icon: Icons.search_rounded,
                    variant: NovaButtonVariant.primary,
                    onPressed: () => context.go('/search'),
                  ),
                  NovaButton(
                    text: 'IMPORTAR',
                    icon: Icons.file_upload_outlined,
                    variant: NovaButtonVariant.secondary,
                    onPressed: () => _importWork(context),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (!_isGridView) {
      return ListView.separated(
        padding: NovaSpacing.pagePadding,
        itemCount: works.length,
        separatorBuilder: (_, _) => const SizedBox(height: NovaSpacing.sm),
        itemBuilder: (context, index) {
          final work = works[index];
          final isFav = state.isFavorite(work.id);

          return NovaCard(
            padding: NovaSpacing.compactCardPadding,
            onTap: () => _openDetails(work),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 60,
                  decoration: BoxDecoration(
                    color: NovaColors.surfaceSecondary,
                    borderRadius: NovaShapes.roundedSm,
                    border: Border.all(color: NovaColors.border),
                  ),
                  child: Icon(
                    work.type == WorkType.book
                        ? Icons.book_outlined
                        : Icons.collections_outlined,
                    color: NovaColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: NovaSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        work.title,
                        style: NovaTypography.titleMedium.copyWith(
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: NovaSpacing.xxs),
                      Text(work.author, style: NovaTypography.bodySmall),
                    ],
                  ),
                ),
                if (isFav)
                  const Padding(
                    padding: EdgeInsets.only(right: NovaSpacing.xs),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 16,
                      color: NovaColors.error,
                    ),
                  ),
                if (work.isDownloaded)
                  const Padding(
                    padding: EdgeInsets.only(right: NovaSpacing.xs),
                    child: Icon(
                      Icons.download_done_rounded,
                      size: 16,
                      color: NovaColors.success,
                    ),
                  ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: NovaColors.textMuted,
                  ),
                  tooltip: 'Remover da Biblioteca',
                  onPressed: () => _confirmRemoveWork(context, work),
                ),
              ],
            ),
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 720;
        final crossAxisCount = isTablet ? 5 : 2;

        return GridView.builder(
          padding: NovaSpacing.pagePadding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: NovaDimensions.gridCardAspectRatio,
            crossAxisSpacing: NovaSpacing.md,
            mainAxisSpacing: NovaSpacing.md,
          ),
          itemCount: works.length,
          itemBuilder: (context, index) {
            final work = works[index];
            final card = work.type == WorkType.comic
                ? NovaComicCard(work: work, onTap: () => _openDetails(work))
                : NovaBookCard(work: work, onTap: () => _openDetails(work));

            return Stack(
              children: [
                Positioned.fill(child: card),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => _confirmRemoveWork(context, work),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: NovaColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRemoveWork(BuildContext context, Work work) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NovaColors.surfaceSecondary,
        title: const Text(
          'Remover da Biblioteca',
          style: NovaTypography.titleMedium,
        ),
        content: Text(
          work.isDownloaded
              ? 'Deseja remover "${work.title}" da sua biblioteca? Os arquivos baixados serão apagados do aparelho.'
              : 'Deseja remover "${work.title}" da sua biblioteca?',
          style: NovaTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'CANCELAR',
              style: TextStyle(color: NovaColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'REMOVER',
              style: TextStyle(
                color: NovaColors.error,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<LibraryBloc>().add(RemoveWorkFromLibraryEvent(work.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${work.title}" removido da biblioteca.'),
          backgroundColor: NovaColors.surfaceSecondary,
        ),
      );
    }
  }

  Future<void> _openDetails(Work work) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => WorkDetailsScreen(work: work)));
    if (mounted) {
      context.read<LibraryBloc>().add(const LoadLibraryEvent());
    }
  }

  Future<void> _importWork(BuildContext context) async {
    final filePicker = getIt<IFilePickerService>();
    final path = await filePicker.pickDocumentFile();
    if (path != null && context.mounted) {
      context.read<LibraryBloc>().add(ImportWorkEvent(path));
    }
  }
}
