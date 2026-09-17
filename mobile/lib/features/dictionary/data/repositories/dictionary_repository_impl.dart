import 'package:dio/dio.dart';
import 'package:fpdart/fpdart.dart';

import '../../domain/entities/word_summary.dart';
import '../../domain/failures/dictionary_failure.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../datasources/dictionary_remote_datasource.dart';

class DictionaryRepositoryImpl implements DictionaryRepository {
  DictionaryRepositoryImpl(this._remoteDatasource);

  final DictionaryRemoteDatasource _remoteDatasource;

  @override
  Future<Either<DictionaryFailure, WordSearchPage>> searchWords({
    required String query,
    required int limit,
    String? cursor,
    String searchIn = 'lemma',
  }) async {
    try {
      final response = await _remoteDatasource.searchWords({
        'q': query,
        'limit': limit,
        'cursor': ?cursor,
        'search_in': searchIn,
      });

      final items = response.data;
      if (items == null) {
        return Either.left(DictionaryFailure(
          response.message ?? 'Pencarian gagal',
          errorCode: response.errorCode,
        ));
      }

      // meta cursor (base-stack Section 13): next_cursor + has_more
      final meta = response.meta;
      return Either.right(WordSearchPage(
        items: items
            .map((dto) => WordSummary(
                  id: dto.id,
                  lemma: dto.lemma,
                  languageCode: dto.languageCode,
                  wordType: dto.wordType,
                  isVerified: dto.isVerified,
                  matchedTranslation: dto.matchedTranslation,
                ))
            .toList(),
        nextCursor: meta?['next_cursor'] as String?,
        hasMore: meta?['has_more'] as bool? ?? false,
      ));
    } on DioException catch (error) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final message = data['message'];
        if (message is String && message.isNotEmpty) {
          return Either.left(DictionaryFailure(message,
              errorCode: data['error_code'] as String?));
        }
      }
      return Either.left(const DictionaryFailure(
          'Pencarian gagal, periksa koneksi'));
    } catch (error) {
      return Either.left(DictionaryFailure(error.toString()));
    }
  }
}
