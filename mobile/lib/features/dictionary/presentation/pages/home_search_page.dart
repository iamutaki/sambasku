import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../providers/dictionary_search_providers.dart';

/// Tab HOME: pencarian kosakata (tampil by default). Endpoint publik -
/// pencarian TANPA login (base-stack: auth hanya untuk kontribusi).
/// TODO(theming): komponen forui saat tema final; TODO(detail): tap item
/// buka halaman detail kata.
class HomeSearchPage extends HookConsumerWidget {
  const HomeSearchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dictionarySearchProvider);
    final notifier = ref.read(dictionarySearchProvider.notifier);
    final controller = useTextEditingController(text: state.query);
    final scroll = useScrollController();

    // infinite scroll: mendekati bawah + hasMore -> loadMore
    useEffect(() {
      void listener() {
        if (scroll.position.pixels >=
            scroll.position.maxScrollExtent - 200) {
          notifier.loadMore();
        }
      }

      scroll.addListener(listener);
      return () => scroll.removeListener(listener);
    }, [scroll]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kamus Sambas'),
        centerTitle: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: controller,
              onChanged: notifier.onQueryChanged,
              decoration: InputDecoration(
                hintText: state.searchIn == 'lemma'
                    ? 'Cari kata Sambas...'
                    : 'Cari kata Indonesia (terjemahan)...',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          controller.clear();
                          notifier.onQueryChanged('');
                        },
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'lemma',
                  label: Text('Sambas -> Indonesia'),
                  icon: Icon(Icons.translate),
                ),
                ButtonSegment(
                  value: 'translation',
                  label: Text('Indonesia -> Sambas'),
                  icon: Icon(Icons.swap_horiz),
                ),
              ],
              selected: {state.searchIn},
              onSelectionChanged: (selection) =>
                  notifier.onSearchInChanged(selection.first),
            ),
          ),
          const Gap(8),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                state.errorMessage!,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: _buildBody(context, state, notifier, scroll),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    dynamic state,
    dynamic notifier,
    ScrollController scroll,
  ) {
    if (state.isLoading) {
      return Skeletonizer(
        enabled: true,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: List.generate(
            6,
            (_) => const ListTile(
              title: Text('memuat hasil pencarian'),
              subtitle: Text('bahasa'),
            ),
          ),
        ),
      );
    }

    if (!state.hasSearched) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 56, color: Colors.grey),
            Gap(8),
            Text('Mulai ketik untuk mencari kosakata'),
          ],
        ),
      );
    }

    if (state.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 56, color: Colors.grey),
            const Gap(8),
            Text('Tidak ada hasil untuk "${state.query}"'),
            const Gap(4),
            const Text(
              'Istilah ini tercatat sebagai peluang kontribusi\n'
              '(fitur usul kata menyusul)',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: state.items.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final item = state.items[index] as dynamic;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            item.lemma as String,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: item.matchedTranslation != null
              ? Text('cocok: ${item.matchedTranslation}')
              : Text('${item.languageCode} - ${item.wordType}'),
          trailing: item.isVerified == true
              ? const Tooltip(
                  message: 'Terverifikasi',
                  child: Icon(Icons.verified, size: 18),
                )
              : null,
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Detail "${item.lemma}" - halaman detail menyusul',
                ),
                duration: const Duration(seconds: 1),
              ),
            );
          },
        );
      },
    );
  }
}
