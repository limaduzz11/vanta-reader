import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vantareader/core/theme/nova_theme.dart';
import 'package:vantareader/domain/entities/work.dart';
import 'package:vantareader/injection.dart';
import 'package:vantareader/presentation/design_system/nova_avatar.dart';
import 'package:vantareader/presentation/design_system/nova_book_card.dart';
import 'package:vantareader/presentation/design_system/nova_button.dart';
import 'package:vantareader/presentation/design_system/nova_comic_card.dart';
import 'package:vantareader/presentation/design_system/nova_filter_chip.dart';
import 'package:vantareader/presentation/screens/work_details_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('novareader_a11y_test_');
    await setupInjection(customStoragePath: tempDir.path, isTest: true);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  final sampleBook = Work(
    id: 'book-a11y-1',
    workKey: 'book:neuromancer',
    title: 'Neuromancer',
    author: 'William Gibson',
    type: WorkType.book,
    primaryLanguage: 'pt-BR',
    description: 'O clássico do cyberpunk.',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    editions: [
      WorkEdition(
        id: 'ed-book-1',
        workId: 'book-a11y-1',
        format: WorkFormat.epub,
        fileSize: 1024 * 1024 * 3,
        pageCount: 320,
        isLocal: true,
        filePath: '/fixtures/neuromancer.epub',
        contentAssets: [
          ContentAsset(
            id: 'asset-book-1',
            editionId: 'ed-book-1',
            format: WorkFormat.epub,
            status: ContentAssetStatus.downloaded,
            localPath: '/fixtures/neuromancer.epub',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      ),
    ],
  );

  final sampleComic = Work(
    id: 'comic-a11y-1',
    workKey: 'comic:watchmen',
    title: 'Watchmen',
    author: 'Alan Moore',
    volume: '1',
    type: WorkType.comic,
    primaryLanguage: 'pt-BR',
    description: 'Quem vigia os vigilantes?',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
    editions: [
      WorkEdition(
        id: 'ed-comic-1',
        workId: 'comic-a11y-1',
        format: WorkFormat.cbz,
        fileSize: 1024 * 1024 * 45,
        pageCount: 400,
        isLocal: true,
        filePath: '/fixtures/watchmen.cbz',
        contentAssets: [
          ContentAsset(
            id: 'asset-comic-1',
            editionId: 'ed-comic-1',
            format: WorkFormat.cbz,
            status: ContentAssetStatus.downloaded,
            localPath: '/fixtures/watchmen.cbz',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
      ),
    ],
  );

  group('Fase N - Acessibilidade & Polish: NovaBookCard', () {
    testWidgets(
      'apresenta árvore Semantics descritiva com título, autor, formato, progresso e download',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: NovaTheme.darkTheme,
            home: Scaffold(
              body: NovaBookCard(
                work: sampleBook,
                width: 140.0,
                progress: 0.45,
                onTap: () {},
              ),
            ),
          ),
        );

        final semanticsFinder = find.descendant(
          of: find.byType(NovaBookCard),
          matching: find.byType(Semantics),
        );
        expect(semanticsFinder, findsWidgets);

        final cardSemantics = tester.widget<Semantics>(semanticsFinder.first);
        expect(cardSemantics.properties.button, isTrue);
        expect(cardSemantics.properties.enabled, isTrue);
        expect(cardSemantics.properties.label, contains('Neuromancer'));
        expect(cardSemantics.properties.label, contains('William Gibson'));
        expect(cardSemantics.properties.label, contains('EPUB'));
        expect(cardSemantics.properties.label, contains('Progresso: 45%'));
        expect(cardSemantics.properties.label, contains('Baixado localmente'));
      },
    );

    testWidgets(
      'configura Hero com tag padrão ou customizada e suporta desativação',
      (tester) async {
        // Com Hero padrão
        await tester.pumpWidget(
          MaterialApp(
            theme: NovaTheme.darkTheme,
            home: Scaffold(body: NovaBookCard(work: sampleBook, width: 140.0)),
          ),
        );

        final heroFinder = find.descendant(
          of: find.byType(NovaBookCard),
          matching: find.byType(Hero),
        );
        expect(heroFinder, findsOneWidget);
        final heroWidget = tester.widget<Hero>(heroFinder);
        expect(heroWidget.tag, 'work_cover_book-a11y-1');

        // Hero desativado
        await tester.pumpWidget(
          MaterialApp(
            theme: NovaTheme.darkTheme,
            home: Scaffold(
              body: NovaBookCard(
                work: sampleBook,
                width: 140.0,
                enableHero: false,
              ),
            ),
          ),
        );
        expect(
          find.descendant(
            of: find.byType(NovaBookCard),
            matching: find.byType(Hero),
          ),
          findsNothing,
        );
      },
    );
  });

  group('Fase N - Acessibilidade & Polish: NovaComicCard', () {
    testWidgets(
      'apresenta árvore Semantics descritiva com título, volume, autor, formato e download',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: NovaTheme.darkTheme,
            home: Scaffold(
              body: NovaComicCard(
                work: sampleComic,
                width: 140.0,
                progress: 0.80,
                onTap: () {},
              ),
            ),
          ),
        );

        final semanticsFinder = find.descendant(
          of: find.byType(NovaComicCard),
          matching: find.byType(Semantics),
        );
        expect(semanticsFinder, findsWidgets);

        final cardSemantics = tester.widget<Semantics>(semanticsFinder.first);
        expect(cardSemantics.properties.button, isTrue);
        expect(cardSemantics.properties.enabled, isTrue);
        expect(cardSemantics.properties.label, contains('Watchmen'));
        expect(cardSemantics.properties.label, contains('Volume 1'));
        expect(cardSemantics.properties.label, contains('Alan Moore'));
        expect(cardSemantics.properties.label, contains('CBZ'));
        expect(cardSemantics.properties.label, contains('Progresso: 80%'));
        expect(cardSemantics.properties.label, contains('Baixado localmente'));
      },
    );

    testWidgets('configura Hero com tag padrão ou customizada', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: NovaTheme.darkTheme,
          home: Scaffold(
            body: NovaComicCard(
              work: sampleComic,
              width: 140.0,
              heroTag: 'custom_comic_tag',
            ),
          ),
        ),
      );

      final heroFinder = find.descendant(
        of: find.byType(NovaComicCard),
        matching: find.byType(Hero),
      );
      expect(heroFinder, findsOneWidget);
      final heroWidget = tester.widget<Hero>(heroFinder);
      expect(heroWidget.tag, 'custom_comic_tag');
    });
  });

  group('Fase N - Acessibilidade: NovaButton & NovaIconButton', () {
    testWidgets(
      'NovaButton cumpre tamanho de toque mínimo (>= 48dp) e semântica',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: NovaTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: NovaButton(
                  text: 'SALVAR CONFIGURAÇÃO',
                  semanticsLabel: 'Salvar alterações do leitor',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );

        final buttonFinder = find.byType(NovaButton);
        final renderSize = tester.getSize(buttonFinder);
        expect(renderSize.height, greaterThanOrEqualTo(48.0));

        final semanticsFinder = find.descendant(
          of: buttonFinder,
          matching: find.byType(Semantics),
        );
        final semanticsWidget = tester.widget<Semantics>(semanticsFinder.first);
        expect(semanticsWidget.properties.button, isTrue);
        expect(semanticsWidget.properties.enabled, isTrue);
        expect(semanticsWidget.properties.label, 'Salvar alterações do leitor');
      },
    );

    testWidgets(
      'NovaButton desabilitado ou em loading reflete enabled: false no Semantics',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: NovaTheme.darkTheme,
            home: const Scaffold(
              body: Center(
                child: NovaButton(text: 'CARREGANDO DADOS', isLoading: true),
              ),
            ),
          ),
        );

        final semanticsFinder = find.descendant(
          of: find.byType(NovaButton),
          matching: find.byType(Semantics),
        );
        final semanticsWidget = tester.widget<Semantics>(semanticsFinder.first);
        expect(semanticsWidget.properties.enabled, isFalse);
      },
    );

    testWidgets(
      'NovaIconButton garante área mínima de 48x48 dp e rótulo semântico/tooltip',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: NovaTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: NovaIconButton(
                  icon: Icons.brightness_6_rounded,
                  tooltip: 'Alternar Tema Monocromático',
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );

        final iconBtnFinder = find.byType(NovaIconButton);
        final renderSize = tester.getSize(iconBtnFinder);
        expect(renderSize.width, greaterThanOrEqualTo(48.0));
        expect(renderSize.height, greaterThanOrEqualTo(48.0));

        expect(find.byType(Tooltip), findsOneWidget);
        final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
        expect(tooltip.message, 'Alternar Tema Monocromático');

        final semanticsWidget = tester.widget<Semantics>(
          find
              .descendant(of: iconBtnFinder, matching: find.byType(Semantics))
              .first,
        );
        expect(semanticsWidget.properties.button, isTrue);
        expect(semanticsWidget.properties.label, 'Alternar Tema Monocromático');
      },
    );
  });

  group('Fase N - Acessibilidade: NovaFilterChip & NovaAvatar', () {
    testWidgets(
      'NovaFilterChip reporta estado selecionado e dimensões acessíveis',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: NovaTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: NovaFilterChip(
                  label: 'Livros EPUB',
                  isSelected: true,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        );

        final chipFinder = find.byType(NovaFilterChip);
        final size = tester.getSize(chipFinder);
        expect(size.height, greaterThanOrEqualTo(36.0));
        expect(size.width, greaterThanOrEqualTo(48.0));

        final semanticsWidget = tester.widget<Semantics>(
          find
              .descendant(of: chipFinder, matching: find.byType(Semantics))
              .first,
        );
        expect(semanticsWidget.properties.button, isTrue);
        expect(semanticsWidget.properties.selected, isTrue);
        expect(semanticsWidget.properties.label, contains('Livros EPUB'));
        expect(semanticsWidget.properties.label, contains('selecionado'));
      },
    );

    testWidgets(
      'NovaAvatar anuncia preset monocromático e reflete interatividade',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: NovaTheme.darkTheme,
            home: Scaffold(
              body: Center(
                child: NovaAvatar(
                  avatarId: 'nova_circle',
                  size: 64.0,
                  onTap: () {},
                ),
              ),
            ),
          ),
        );

        final avatarFinder = find.byType(NovaAvatar);
        final semanticsWidget = tester.widget<Semantics>(
          find
              .descendant(of: avatarFinder, matching: find.byType(Semantics))
              .first,
        );
        expect(semanticsWidget.properties.button, isTrue);
        expect(
          semanticsWidget.properties.label,
          'Avatar monocromático: Eclipse',
        );
      },
    );
  });

  group('Fase N - WorkDetailsScreen: Hero & Semântica', () {
    testWidgets(
      'exibe Hero na capa e botões com marcações semânticas de alta acessibilidade',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: NovaTheme.darkTheme,
            home: WorkDetailsScreen(work: sampleBook),
          ),
        );
        await tester.pumpAndSettle();

        // Verifica presença do Hero na capa
        final heroFinder = find.byType(Hero);
        expect(heroFinder, findsWidgets);
        final coverHero = tester.widget<Hero>(heroFinder.first);
        expect(coverHero.tag, 'work_cover_book-a11y-1');

        // Verifica botão LER AGORA com Semantics
        expect(find.text('LER AGORA'), findsOneWidget);
        final lerAgoraSemantics = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              w.properties.label == 'Iniciar leitura de Neuromancer',
        );
        expect(lerAgoraSemantics, findsOneWidget);

        // Verifica botão BAIXAR com Semantics
        expect(find.text('BAIXAR'), findsOneWidget);
        final baixarSemantics = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              w.properties.label != null &&
              w.properties.label!.contains('Baixar edição EPUB'),
        );
        expect(baixarSemantics, findsOneWidget);

        // Verifica Semantics no botão de Favoritos da AppBar
        final favSemantics = find.byWidgetPredicate(
          (w) =>
              w is Semantics &&
              w.properties.button == true &&
              (w.properties.label == 'Adicionar aos Favoritos' ||
                  w.properties.label == 'Remover dos Favoritos'),
        );
        expect(favSemantics, findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
