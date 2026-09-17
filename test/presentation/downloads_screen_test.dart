import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/download/download_manager.dart';
import 'package:vantareader/core/download/download_progress_snapshot.dart';
import 'package:vantareader/core/storage/storage_manager.dart';
import 'package:vantareader/core/theme/nova_theme.dart';
import 'package:vantareader/domain/entities/download_item.dart';
import 'package:vantareader/domain/repositories/i_download_repository.dart';
import 'package:vantareader/domain/repositories/i_library_repository.dart';
import 'package:vantareader/domain/usecases/downloads/download_usecases.dart';
import 'package:vantareader/presentation/blocs/downloads/downloads_bloc.dart';
import 'package:vantareader/presentation/blocs/downloads/downloads_state.dart';
import 'package:vantareader/presentation/screens/downloads_screen.dart';

class _FakeDownloadRepo implements IDownloadRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<List<DownloadItem>> getAllDownloads() async => [];
}

class _FakeLibraryRepo implements ILibraryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeStorageManager implements StorageManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestDownloadsBloc extends DownloadsBloc {
  TestDownloadsBloc({super.initialState})
    : super(
        getDownloads: GetDownloadsUseCase(
          DownloadManager(
            downloadRepository: _FakeDownloadRepo(),
            libraryRepository: _FakeLibraryRepo(),
            storageManager: _FakeStorageManager(),
          ),
        ),
        pauseDownload: PauseDownloadUseCase(
          DownloadManager(
            downloadRepository: _FakeDownloadRepo(),
            libraryRepository: _FakeLibraryRepo(),
            storageManager: _FakeStorageManager(),
          ),
        ),
        resumeDownload: ResumeDownloadUseCase(
          DownloadManager(
            downloadRepository: _FakeDownloadRepo(),
            libraryRepository: _FakeLibraryRepo(),
            storageManager: _FakeStorageManager(),
          ),
        ),
        cancelDownload: CancelDownloadUseCase(
          DownloadManager(
            downloadRepository: _FakeDownloadRepo(),
            libraryRepository: _FakeLibraryRepo(),
            storageManager: _FakeStorageManager(),
          ),
        ),
        retryDownload: RetryDownloadUseCase(
          DownloadManager(
            downloadRepository: _FakeDownloadRepo(),
            libraryRepository: _FakeLibraryRepo(),
            storageManager: _FakeStorageManager(),
          ),
        ),
        deleteDownload: DeleteDownloadUseCase(
          DownloadManager(
            downloadRepository: _FakeDownloadRepo(),
            libraryRepository: _FakeLibraryRepo(),
            storageManager: _FakeStorageManager(),
          ),
        ),
        clearCompletedDownloads: ClearCompletedDownloadsUseCase(
          DownloadManager(
            downloadRepository: _FakeDownloadRepo(),
            libraryRepository: _FakeLibraryRepo(),
            storageManager: _FakeStorageManager(),
          ),
        ),
      );

  void emitDirect(DownloadsState newState) {
    emit(newState);
  }
}

void main() {
  final sampleItems = [
    DownloadItem(
      id: 'dl-1',
      workId: 'work-1',
      editionId: 'ed-1',
      title: 'Neuromancer',
      targetPath: '/books/neuromancer.epub',
      downloadUrl: 'mock://download/1',
      totalBytes: 2048 * 1024,
      downloadedBytes: 1024 * 1024,
      status: DownloadStatus.downloading,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    DownloadItem(
      id: 'dl-2',
      workId: 'work-2',
      editionId: 'ed-2',
      title: 'Watchmen',
      targetPath: '/comics/watchmen.cbz',
      downloadUrl: 'mock://download/2',
      totalBytes: 10 * 1024 * 1024,
      downloadedBytes: 5 * 1024 * 1024,
      status: DownloadStatus.paused,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    DownloadItem(
      id: 'dl-3',
      workId: 'work-3',
      editionId: 'ed-3',
      title: 'Fundação',
      targetPath: '/books/fundacao.epub',
      downloadUrl: 'mock://download/3',
      totalBytes: 1024 * 1024,
      downloadedBytes: 1024 * 1024,
      status: DownloadStatus.completed,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  testWidgets('DownloadsScreen exibe EmptyState quando não houver downloads', (
    tester,
  ) async {
    final testBloc = TestDownloadsBloc(
      initialState: const DownloadsLoaded(downloads: []),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: NovaTheme.darkTheme,
        home: DownloadsScreen(bloc: testBloc),
      ),
    );

    await tester.pump();

    expect(find.text('Downloads'), findsOneWidget);
    expect(find.text('Nenhum Download Ativo'), findsOneWidget);
    expect(
      find.text('As transferências e arquivos baixados aparecerão aqui.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'DownloadsScreen renderiza cards com velocidade, ETA e botões de ação corretos',
    (tester) async {
      const activeSnapshot = DownloadProgressSnapshot(
        downloadId: 'dl-1',
        status: DownloadStatus.downloading,
        downloadedBytes: 1024 * 1024,
        totalBytes: 2048 * 1024,
        speedBytesPerSecond: 1.5 * 1024 * 1024, // 1.5 MB/s
        etaSeconds: 10,
      );

      final testBloc = TestDownloadsBloc(
        initialState: DownloadsLoaded(
          downloads: sampleItems,
          progressMap: const {'dl-1': activeSnapshot},
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: NovaTheme.darkTheme,
          home: DownloadsScreen(bloc: testBloc),
        ),
      );

      await tester.pump();

      // 1. Verifica títulos das obras
      expect(find.text('Neuromancer'), findsOneWidget);
      expect(find.text('Watchmen'), findsOneWidget);
      expect(find.text('Fundação'), findsOneWidget);

      // 2. Verifica métricas em tempo real no item ativo (velocidade e ETA)
      expect(find.textContaining('1.5 MB/s'), findsOneWidget);
      expect(find.textContaining('ETA: 10s'), findsOneWidget);

      // 3. Verifica botões de ação presentes na tela
      expect(
        find.byIcon(Icons.pause_rounded),
        findsOneWidget,
      ); // Botão pausar de Neuromancer
      expect(
        find.byIcon(Icons.play_arrow_rounded),
        findsOneWidget,
      ); // Botão retomar de Watchmen
      expect(
        find.byIcon(Icons.cleaning_services_rounded),
        findsOneWidget,
      ); // Botão limpar concluídos
      expect(
        find.byIcon(Icons.delete_outline_rounded),
        findsOneWidget,
      ); // Botão excluir de Fundação
    },
  );
}
