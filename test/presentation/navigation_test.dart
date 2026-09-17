import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/injection.dart';
import 'package:vantareader/main.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('novareader_widget_test_');
    await setupInjection(customStoragePath: tempDir.path, isTest: true);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Navegação e UI Shell', () {
    testWidgets(
      'renderiza aplicação no tema Monochromatic Minimalism e navega entre abas no celular',
      (tester) async {
        // Configura tela de celular (400 x 800)
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(const VantaReaderApp(initialLocation: '/home'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verifica elementos da Home
        expect(find.text('VANTA Reader'), findsOneWidget);
        expect(find.text('LIVROS POPULARES'), findsOneWidget);
        expect(find.text('CONTINUAR LENDO'), findsNothing);

        // Verifica itens do BottomNavigationBar
        expect(find.text('Início'), findsOneWidget);
        expect(find.text('Busca'), findsOneWidget);
        expect(find.text('Biblioteca'), findsOneWidget);
        expect(find.text('Downloads'), findsOneWidget);
        expect(find.text('Perfil'), findsOneWidget);

        // Navega para Busca
        await tester.tap(find.text('Busca'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(TextField), findsOneWidget);

        // Navega para Biblioteca
        await tester.tap(find.text('Biblioteca'));
        await tester.pump();
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
        expect(find.text('Todos (0)'), findsOneWidget);
        expect(find.text('BUSCAR OBRAS'), findsOneWidget);

        // Navega para Downloads
        await tester.tap(find.text('Downloads'));
        await tester.pump();
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();
        expect(find.text('Nenhum Download Ativo'), findsOneWidget);

        // Navega para Perfil
        await tester.tap(find.text('Perfil'));
        await tester.pump();
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 500));
        });
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Leitor'), findsOneWidget);
        expect(find.text('Livros Lidos'), findsOneWidget);
      },
    );

    testWidgets(
      'exibe NavigationRail lateral em telas de Tablet (largura >= 720)',
      (tester) async {
        // Configura tela de Tablet (900 x 1200)
        tester.view.physicalSize = const Size(900, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(const VantaReaderApp(initialLocation: '/home'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // NavigationRail deve estar presente
        expect(find.byType(NavigationRail), findsOneWidget);
        // BottomNavigationBar NÃO deve estar presente em tablet
        expect(find.byType(BottomNavigationBar), findsNothing);
      },
    );
  });
}
