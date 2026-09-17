// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dictionary_domain_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(searchWordsUseCase)
final searchWordsUseCaseProvider = SearchWordsUseCaseProvider._();

final class SearchWordsUseCaseProvider
    extends
        $FunctionalProvider<
          SearchWordsUseCase,
          SearchWordsUseCase,
          SearchWordsUseCase
        >
    with $Provider<SearchWordsUseCase> {
  SearchWordsUseCaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'searchWordsUseCaseProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$searchWordsUseCaseHash();

  @$internal
  @override
  $ProviderElement<SearchWordsUseCase> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SearchWordsUseCase create(Ref ref) {
    return searchWordsUseCase(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SearchWordsUseCase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SearchWordsUseCase>(value),
    );
  }
}

String _$searchWordsUseCaseHash() =>
    r'c9a95b5314fc2b144ac122a9df2c06e3dca937a7';
