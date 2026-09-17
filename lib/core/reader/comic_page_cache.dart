import 'dart:collection';
import 'dart:typed_data';
import '../logging/app_logger.dart';

/// Gerenciador de cache em memória LRU (Least Recently Used) para páginas de quadrinhos
class ComicPageCache {
  final int maxCapacity;
  final int maxBytesCapacity; // Em bytes (padrão: 64 MB)
  final LinkedHashMap<int, Uint8List> _cache = LinkedHashMap<int, Uint8List>();
  int _currentBytes = 0;
  int _hits = 0;
  int _misses = 0;
  int _evictionsCount = 0;

  ComicPageCache({
    this.maxCapacity = 7,
    this.maxBytesCapacity = 64 * 1024 * 1024,
  });

  int get hits => _hits;
  int get misses => _misses;
  int get evictionsCount => _evictionsCount;
  double get hitRate =>
      (_hits + _misses) == 0 ? 0.0 : _hits / (_hits + _misses);

  /// Armazena os bytes da página no cache, aplicando política LRU por itens e limite de bytes
  void put(int pageIndex, Uint8List bytes) {
    if (_cache.containsKey(pageIndex)) {
      final old = _cache.remove(pageIndex);
      _currentBytes -= (old?.length ?? 0);
    }

    // Expulsa páginas antigas enquanto capacidade ou orçamento de bytes for excedido
    while (_cache.isNotEmpty &&
        (_cache.length >= maxCapacity ||
            (_currentBytes + bytes.length > maxBytesCapacity))) {
      final oldestKey = _cache.keys.first;
      final evicted = _cache.remove(oldestKey);
      if (evicted != null) {
        _currentBytes -= evicted.length;
        _evictionsCount++;
        AppLogger.debug(
          LogCategory.reader,
          'Página $oldestKey removida do cache LRU (${evicted.length ~/ 1024} KB liberados).',
        );
      }
    }

    _cache[pageIndex] = bytes;
    _currentBytes += bytes.length;
  }

  /// Recupera os bytes da página e a move para o final da fila (mais recente)
  Uint8List? get(int pageIndex) {
    final bytes = _cache.remove(pageIndex);
    if (bytes != null) {
      _cache[pageIndex] = bytes;
      _hits++;
      return bytes;
    }
    _misses++;
    return null;
  }

  bool contains(int pageIndex) => _cache.containsKey(pageIndex);

  void evict(int pageIndex) {
    final evicted = _cache.remove(pageIndex);
    if (evicted != null) {
      _currentBytes -= evicted.length;
      _evictionsCount++;
    }
  }

  void clear() {
    _cache.clear();
    _currentBytes = 0;
  }

  int get length => _cache.length;

  int get totalBytes => _currentBytes;
}
