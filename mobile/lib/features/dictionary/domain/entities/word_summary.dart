/// Ringkasan kata hasil pencarian (entity domain).
class WordSummary {
  const WordSummary({
    required this.id,
    required this.lemma,
    required this.languageCode,
    required this.wordType,
    required this.isVerified,
    this.matchedTranslation,
  });

  final String id;
  final String lemma;
  final String languageCode;
  final String wordType;
  final bool isVerified;

  /// Hanya terisi pencarian arah Indonesia -> Sambas (search_in=translation):
  /// teks terjemahan yang cocok, untuk label "makan -> makatn".
  final String? matchedTranslation;
}

/// Satu halaman hasil cursor-based (base-stack Section 13).
class WordSearchPage {
  const WordSearchPage({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  final List<WordSummary> items;
  final String? nextCursor;
  final bool hasMore;
}
