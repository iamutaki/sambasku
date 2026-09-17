import 'package:fpdart/fpdart.dart';

import '../entities/word_summary.dart';
import '../failures/dictionary_failure.dart';

abstract interface class DictionaryRepository {
  /// Pencarian kata (cursor-based). [searchIn] 'lemma' = Sambas->Indonesia
  /// (default), 'translation' = Indonesia->Sambas (reverse).
  Future<Either<DictionaryFailure, WordSearchPage>> searchWords({
    required String query,
    required int limit,
    String? cursor,
    String searchIn = 'lemma',
  });
}
