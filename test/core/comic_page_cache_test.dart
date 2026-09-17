import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:vantareader/core/reader/comic_page_cache.dart';

void main() {
  group('ComicPageCache (Fase G - LRU Memory Cache)', () {
    test('Armazena e recupera bytes de páginas no cache', () {
      final cache = ComicPageCache(maxCapacity: 3);
      final dummyBytes = Uint8List.fromList([1, 2, 3]);

      cache.put(0, dummyBytes);
      expect(cache.contains(0), isTrue);
      expect(cache.get(0), equals(dummyBytes));
      expect(cache.length, equals(1));
      expect(cache.totalBytes, equals(3));
    });

    test(
      'Aplica política LRU expulsando a página mais antiga quando capacidade máxima é atingida',
      () {
        final cache = ComicPageCache(maxCapacity: 3);

        cache.put(0, Uint8List(100));
        cache.put(1, Uint8List(100));
        cache.put(2, Uint8List(100));
        expect(cache.length, equals(3));

        // Ao inserir a 4ª página, a página 0 (mais antiga) deve ser expulsa
        cache.put(3, Uint8List(100));
        expect(cache.length, equals(3));
        expect(cache.contains(0), isFalse);
        expect(cache.contains(1), isTrue);
        expect(cache.contains(2), isTrue);
        expect(cache.contains(3), isTrue);
      },
    );

    test('Acessar página existente renova sua posição recente no LRU', () {
      final cache = ComicPageCache(maxCapacity: 3);

      cache.put(0, Uint8List(100));
      cache.put(1, Uint8List(100));
      cache.put(2, Uint8List(100));

      // Acessa a página 0 (torna-se a mais recente)
      final retrieved = cache.get(0);
      expect(retrieved, isNotNull);

      // Ao inserir a página 3, a página 1 (agora a mais antiga) deve ser expulsa
      cache.put(3, Uint8List(100));
      expect(cache.contains(1), isFalse);
      expect(cache.contains(0), isTrue);
      expect(cache.contains(2), isTrue);
      expect(cache.contains(3), isTrue);
    });

    test('Limpa todo o cache e remove páginas individuais', () {
      final cache = ComicPageCache(maxCapacity: 5);
      cache.put(0, Uint8List(50));
      cache.put(1, Uint8List(50));

      cache.evict(0);
      expect(cache.contains(0), isFalse);
      expect(cache.length, equals(1));

      cache.clear();
      expect(cache.length, equals(0));
      expect(cache.totalBytes, equals(0));
    });
  });
}
