import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vantareader/core/services/file_picker_service.dart';
import 'package:vantareader/core/theme/nova_theme.dart';
import 'package:vantareader/domain/usecases/get_library_works_usecase.dart';
import 'package:vantareader/domain/usecases/import_work_usecase.dart';
import 'package:vantareader/domain/usecases/search_local_library_usecase.dart';
import 'package:vantareader/domain/usecases/toggle_favorite_usecase.dart';
import 'package:vantareader/injection.dart';
import 'package:vantareader/presentation/blocs/library/library_bloc.dart';
import 'package:vantareader/presentation/blocs/library/library_state.dart';
import 'package:vantareader/presentation/screens/library_screen.dart';

class MockFilePickerService implements IFilePickerService {
  String? selectedPath;
  bool wasCalled = false;

  @override
  Future<String?> pickDocumentFile() async {
    wasCalled = true;
    return selectedPath;
  }
}

class TestLibraryBloc extends LibraryBloc {
  TestLibraryBloc({
    required super.getLibraryWorks,
    required super.toggleFavorite,
    required super.searchLocalLibrary,
    super.importWork,
  });

  void emitDirect(LibraryState newState) {
    emit(newState);
  }
}

void main() {
  late Directory tempDir;
  late MockFilePickerService mockPicker;
  late TestLibraryBloc testBloc;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'novareader_import_ui_test_',
    );

    await setupInjection(customStoragePath: tempDir.path, isTest: true);

    mockPicker = MockFilePickerService();
    if (getIt.isRegistered<IFilePickerService>()) {
      await getIt.unregister<IFilePickerService>();
    }
    getIt.registerSingleton<IFilePickerService>(mockPicker);

    testBloc = TestLibraryBloc(
      getLibraryWorks: getIt<GetLibraryWorksUseCase>(),
      toggleFavorite: getIt<ToggleFavoriteUseCase>(),
      searchLocalLibrary: getIt<SearchLocalLibraryUseCase>(),
      importWork: getIt<ImportWorkUseCase>(),
    );

    if (getIt.isRegistered<LibraryBloc>()) {
      await getIt.unregister<LibraryBloc>();
    }
    getIt.registerFactory<LibraryBloc>(() => testBloc);
  });

  tearDown(() async {
    if (getIt.isRegistered<IFilePickerService>()) {
      await getIt.unregister<IFilePickerService>();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('Fase E — UI de Importação na LibraryScreen', () {
    testWidgets(
      'exibe botões de importação e aciona IFilePickerService ao clicar',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          MaterialApp(theme: NovaTheme.darkTheme, home: const LibraryScreen()),
        );

        // Aguarda carregamento inicial do catálogo
        await tester.pump();
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();

        // 1. Verifica presença dos botões de importar (AppBar e FAB)
        expect(find.byIcon(Icons.file_upload_outlined), findsWidgets);
        expect(find.text('Importar'), findsOneWidget);

        // 2. Toca no botão de importar
        await tester.tap(find.text('Importar'));
        await tester.pump();

        // 3. Valida que o serviço de seleção de arquivos foi acionado
        expect(mockPicker.wasCalled, isTrue);
      },
    );

    testWidgets(
      'exibe SnackBar monocromática de sucesso quando obra é importada',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;

        await tester.pumpWidget(
          MaterialApp(theme: NovaTheme.darkTheme, home: const LibraryScreen()),
        );

        await tester.pump();
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump();

        // Dispara emissão de obra importada no LibraryBloc
        testBloc.emitDirect(
          const LibraryLoaded(
            works: [],
            favoriteWorkIds: {},
            lastImportedTitle: 'Memórias Póstumas',
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(
          find.text('Obra "Memórias Póstumas" importada com sucesso!'),
          findsOneWidget,
        );
      },
    );
  });
}
