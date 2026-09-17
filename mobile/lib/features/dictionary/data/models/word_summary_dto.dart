import 'package:freezed_annotation/freezed_annotation.dart';

part 'word_summary_dto.freezed.dart';
part 'word_summary_dto.g.dart';

@freezed
abstract class WordSummaryDto with _$WordSummaryDto {
  const factory WordSummaryDto({
    required String id,
    required String lemma,
    @JsonKey(name: 'language_id') required String languageId,
    @JsonKey(name: 'language_code') required String languageCode,
    @JsonKey(name: 'word_type') required String wordType,
    @JsonKey(name: 'is_verified') required bool isVerified,
    @JsonKey(name: 'matched_translation') String? matchedTranslation,
  }) = _WordSummaryDto;

  factory WordSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$WordSummaryDtoFromJson(json);
}
