import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/reader/comic_content_parser.dart';
import 'package:vantareader/core/reader/comic_models.dart';
import 'package:vantareader/core/reader/comic_page_cache.dart';
import 'package:vantareader/core/theme/nova_theme.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/repositories/i_library_repository.dart';
import 'package:vantareader/domain/usecases/get_reading_progress_usecase.dart';
import 'package:vantareader/domain/usecases/save_reading_progress_usecase.dart';
import 'package:vantareader/injection.dart';
import 'package:vantareader/presentation/blocs/comic_reader/comic_reader_bloc.dart';
import 'package:vantareader/presentation/blocs/comic_reader/comic_reader_state.dart';
import 'package:vantareader/presentation/screens/reader/comic_reader_screen.dart';

class MockGetReadingProgressUseCase extends GetReadingProgressUseCase {
  MockGetReadingProgressUseCase() : super(_DummyLibraryRepo());
}

class MockSaveReadingProgressUseCase extends SaveReadingProgressUseCase {
  MockSaveReadingProgressUseCase() : super(_DummyLibraryRepo());
}

class _DummyLibraryRepo implements ILibraryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestComicReaderBloc extends ComicReaderBloc {
  TestComicReaderBloc({super.initialState})
    : super(
        contentParser: ComicContentParser(
          cache: ComicPageCache(maxCapacity: 5),
        ),
        getProgress: MockGetReadingProgressUseCase(),
        saveProgress: MockSaveReadingProgressUseCase(),
      );

  void emitDirect(ComicReaderState newState) {
    emit(newState);
  }
}

void main() {
  final sampleComic = Work(
    id: 'work-widget-comic-test',
    workKey: 'comic:sandman',
    title: 'Sandman: Prelúdios & Noturnos',
    author: 'Neil Gaiman',
    type: WorkType.comic,
    primaryLanguage: 'pt-BR',
    description: 'Um clássico dos quadrinhos.',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleEdition = WorkEdition(
    id: 'ed-sandman-widget',
    workId: sampleComic.id,
    format: WorkFormat.cbz,
    fileSize: 1024 * 1024,
    pageCount: 8,
    isLocal: true,
  );

  final samplePages = List.generate(
    8,
    (index) => ComicPage(
      pageIndex: index,
      fileName: 'page_${(index + 1).toString().padLeft(2, '0')}.jpg',
      fileSize: 50000,
    ),
  );

  final sampleContent = ComicContent(
    workId: sampleComic.id,
    title: sampleComic.title,
    pages: samplePages,
  );

  setUpAll(() {
    if (!getIt.isRegistered<ComicPageCache>()) {
      getIt.registerSingleton<ComicPageCache>(ComicPageCache(maxCapacity: 10));
    }
    if (!getIt.isRegistered<ComicContentParser>()) {
      getIt.registerSingleton<ComicContentParser>(
        ComicContentParser(cache: getIt<ComicPageCache>()),
      );
    }
  });

  testWidgets(
    'ComicReaderScreen renderiza controles, suporta modo imersivo e modais de páginas e ajustes',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final loadedState = ComicReaderLoaded(
        work: sampleComic,
        edition: sampleEdition,
        content: sampleContent,
        currentPageIndex: 0,
        totalPages: 8,
        percentage: 0.12,
        areControlsVisible: true,
        settings: const ComicReaderSettings(),
      );

      final testBloc = TestComicReaderBloc(initialState: loadedState);

      await tester.pumpWidget(
        MaterialApp(
          theme: NovaTheme.darkTheme,
          home: ComicReaderScreen(
            work: sampleComic,
            edition: sampleEdition,
            bloc: testBloc,
          ),
        ),
      );

      await tester.pump();

      // 1. Verifica renderização do título da obra na AppBar e número de página (AppBar e BottomBar)
      expect(find.text('Sandman: Prelúdios & Noturnos'), findsOneWidget);
      expect(find.text('Página 1 de 8'), findsNWidgets(2));

      // 2. Verifica presença dos botões da AppBar superior (Grade de páginas e Configurações)
      final gridButton = find.byIcon(Icons.grid_view_rounded);
      final tuneButton = find.byIcon(Icons.tune_rounded);
      expect(gridButton, findsOneWidget);
      expect(tuneButton, findsOneWidget);

      // 3. Verifica botões de navegação da barra inferior
      expect(find.text('Anterior'), findsOneWidget);
      expect(find.text('Próxima'), findsOneWidget);
      expect(find.text('12%'), findsOneWidget);

      // 4. Alterna visibilidade dos controles para fullscreen imersivo
      testBloc.emitDirect(loadedState.copyWith(areControlsVisible: false));
      await tester.pump();

      // 5. Restaura visibilidade dos controles
      testBloc.emitDirect(loadedState.copyWith(areControlsVisible: true));
      await tester.pump();

      // 6. Abre BottomSheet da Grade de Páginas
      await tester.tap(gridButton);
      await tester.pumpAndSettle();

      expect(find.text('Páginas do Quadrinho'), findsOneWidget);
      expect(find.text('8 páginas'), findsOneWidget);

      // Fecha o modal tocando fora / dando pop
      Navigator.of(tester.element(find.text('Páginas do Quadrinho'))).pop();
      await tester.pumpAndSettle();

      // 7. Abre BottomSheet de Configurações de Leitura
      await tester.tap(tuneButton);
      await tester.pumpAndSettle();

      expect(find.text('Ajustes do Leitor de HQs'), findsOneWidget);
      expect(find.text('Página Única'), findsOneWidget);
      expect(find.text('Webtoon (Vertical)'), findsOneWidget);
      expect(find.text('Largura'), findsOneWidget);
      expect(find.text('Tela'), findsOneWidget);
      expect(find.text('Altura'), findsOneWidget);
      expect(
        find.text('Leitura da Direita para a Esquerda (Mangá)'),
        findsOneWidget,
      );

      // Toca no chip Webtoon (Vertical) para alternar o modo
      await tester.tap(find.text('Webtoon (Vertical)'));
      await tester.pumpAndSettle();

      // Fecha o modal de configurações
      Navigator.of(tester.element(find.text('Ajustes do Leitor de HQs'))).pop();
      await tester.pumpAndSettle();

      // 8. Verifica que a ListView de rolagem contínua passou a ser exibida
      expect(find.byType(ListView), findsOneWidget);
    },
  );
}
