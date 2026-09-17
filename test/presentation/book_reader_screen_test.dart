import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/reader/book_content_parser.dart';
import 'package:vantareader/core/reader/book_models.dart';
import 'package:vantareader/core/theme/nova_theme.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/domain/repositories/i_library_repository.dart';
import 'package:vantareader/domain/usecases/get_reading_progress_usecase.dart';
import 'package:vantareader/domain/usecases/save_reading_progress_usecase.dart';
import 'package:vantareader/presentation/blocs/book_reader/book_reader_bloc.dart';
import 'package:vantareader/presentation/blocs/book_reader/book_reader_state.dart';
import 'package:vantareader/presentation/screens/reader/book_reader_screen.dart';

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

class TestBookReaderBloc extends BookReaderBloc {
  TestBookReaderBloc({super.initialState})
    : super(
        contentParser: const BookContentParser(),
        getProgress: MockGetReadingProgressUseCase(),
        saveProgress: MockSaveReadingProgressUseCase(),
      );

  void emitDirect(BookReaderState newState) {
    emit(newState);
  }
}

void main() {
  final sampleWork = Work(
    id: 'work-widget-reader',
    workKey: 'book:fundacao',
    title: 'Fundação',
    author: 'Isaac Asimov',
    type: WorkType.book,
    primaryLanguage: 'pt-BR',
    description: 'O início do Império Galáctico.',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final sampleEdition = WorkEdition(
    id: 'ed-fundacao',
    workId: sampleWork.id,
    format: WorkFormat.epub,
    fileSize: 2048,
    pageCount: 10,
    isLocal: true,
  );

  const sampleContent = BookContent(
    workId: 'work-widget-reader',
    title: 'Fundação',
    totalEstimatedPages: 10,
    chapters: [
      BookChapter(
        id: 'ch-1',
        title: 'Capítulo I — Os Psicohistoriadores',
        content: 'Hari Seldon observou a cúpula de Trantor com serenidade.',
        orderIndex: 0,
        estimatedPages: 5,
      ),
      BookChapter(
        id: 'ch-2',
        title: 'Capítulo II — Os Enciclopedistas',
        content: 'Terminus era um planeta nos confins da Galáxia.',
        orderIndex: 1,
        estimatedPages: 5,
      ),
    ],
  );

  testWidgets(
    'BookReaderScreen renderiza conteúdo textual e suporta alternância de controles e modais',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final loadedState = BookReaderLoaded(
        work: sampleWork,
        edition: sampleEdition,
        content: sampleContent,
        currentChapterIndex: 0,
        currentPage: 1,
        totalPages: 10,
        percentage: 10.0,
        areControlsVisible: true,
        typography: const TypographySettings(),
      );

      final testBloc = TestBookReaderBloc(initialState: loadedState);

      await tester.pumpWidget(
        MaterialApp(
          theme: NovaTheme.darkTheme,
          home: BookReaderScreen(
            work: sampleWork,
            edition: sampleEdition,
            bloc: testBloc,
          ),
        ),
      );

      await tester.pump();

      // 1. Verifica renderização do título da obra na AppBar e título do capítulo (na barra e no corpo)
      expect(find.text('Fundação'), findsOneWidget);
      expect(find.text('Capítulo I — Os Psicohistoriadores'), findsNWidgets(2));
      expect(
        find.textContaining('Hari Seldon observou a cúpula'),
        findsOneWidget,
      );

      // 2. Verifica presença dos botões da AppBar superior (Sumário e Tipografia)
      final tocButton = find.byIcon(Icons.list_alt_rounded);
      final typoButton = find.byIcon(Icons.format_size_rounded);
      expect(tocButton, findsOneWidget);
      expect(typoButton, findsOneWidget);

      // 3. Verifica botões de navegação da barra inferior
      expect(find.text('Anterior'), findsOneWidget);
      expect(find.text('Próxima'), findsOneWidget);

      // 4. Alterna visibilidade dos controles para fullscreen imersivo
      testBloc.emitDirect(loadedState.copyWith(areControlsVisible: false));
      await tester.pump();
    },
  );

  testWidgets(
    'BookReaderScreen suporta tema Kindle (pagina branca/texto preto) e tamanhos 22pt e 24pt',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final kindleState = BookReaderLoaded(
        work: sampleWork,
        edition: sampleEdition,
        content: sampleContent,
        currentChapterIndex: 0,
        currentPage: 1,
        totalPages: 10,
        percentage: 10.0,
        areControlsVisible: true,
        typography: const TypographySettings(
          fontSize: 22.0,
          themeMode: 'kindle',
        ),
      );

      final testBloc = TestBookReaderBloc(initialState: kindleState);

      await tester.pumpWidget(
        MaterialApp(
          theme: NovaTheme.darkTheme,
          home: BookReaderScreen(
            work: sampleWork,
            edition: sampleEdition,
            bloc: testBloc,
          ),
        ),
      );

      await tester.pump();

      // Verifica que o Scaffold de leitura está com fundo branco Kindle
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));

      // Abre o modal de tipografia
      final typoButton = find.byIcon(Icons.format_size_rounded);
      await tester.tap(typoButton);
      await tester.pumpAndSettle();

      // Verifica se as opções solicitadas existem no modal
      expect(find.text('Kindle'), findsOneWidget);
      expect(find.text('OLED Preto'), findsOneWidget);
      expect(find.text('22 pt'), findsWidgets);
      expect(find.text('24 pt'), findsOneWidget);
    },
  );
}
