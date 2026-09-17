import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import '../../domain/entities/work.dart';

/// Metadados extraídos de um arquivo local durante a importação
class ExtractedMetadata extends Equatable {
  final String title;
  final String author;
  final String? description;
  final String primaryLanguage;
  final WorkType type;
  final WorkFormat format;
  final String? series;
  final String? volume;
  final String? publisher;
  final String? publishedDate;
  final String? isbn;
  final int pageCount;
  final int fileSize;
  final Uint8List? coverBytes;
  final String? coverImageExtension;

  const ExtractedMetadata({
    required this.title,
    required this.author,
    this.description,
    this.primaryLanguage = 'pt-BR',
    required this.type,
    required this.format,
    this.series,
    this.volume,
    this.publisher,
    this.publishedDate,
    this.isbn,
    this.pageCount = 0,
    this.fileSize = 0,
    this.coverBytes,
    this.coverImageExtension = 'jpg',
  });

  @override
  List<Object?> get props => [
    title,
    author,
    primaryLanguage,
    type,
    format,
    series,
    volume,
    pageCount,
    fileSize,
  ];
}
