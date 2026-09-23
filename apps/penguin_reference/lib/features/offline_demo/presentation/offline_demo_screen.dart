import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:penguin_offline/penguin_offline.dart';

import '../domain/note.dart';
import 'offline_demo_providers.dart';

/// Demonstrates the shell's offline capability end-to-end: a cached list
/// of [Note]s (each showing a [StaleDataChip] for its cache age), an "add
/// note" form that writes through [NotesController.addNote] (cache write +
/// [SyncQueue.enqueue]), and a snackbar whenever a write dead-letters
/// (`penguinm.offline_demo`, spec §4.7).
class OfflineDemoScreen extends ConsumerStatefulWidget {
  /// Creates the offline demo screen.
  const OfflineDemoScreen({super.key});

  @override
  ConsumerState<OfflineDemoScreen> createState() => _OfflineDemoScreenState();
}

class _OfflineDemoScreenState extends ConsumerState<OfflineDemoScreen> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _textController.text;
    if (!isValidNoteText(text)) return;
    await ref.read(notesControllerProvider.notifier).addNote(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<PendingWrite>>(offlineDemoDeadLettersProvider, (
      previous,
      next,
    ) {
      next.whenData((write) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Note ${write.id} couldn't be synced and was dropped",
            ),
          ),
        );
      });
    });

    final notesAsync = ref.watch(notesControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Offline Demo')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      labelText: 'New note',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _submit, child: const Text('Add note')),
              ],
            ),
          ),
          Expanded(
            child: switch (notesAsync) {
              AsyncData(:final value) =>
                value.isEmpty
                    ? const Center(child: Text('No notes yet'))
                    : ListView.builder(
                        itemCount: value.length,
                        itemBuilder: (context, index) {
                          final note = value[index];
                          return ListTile(
                            title: Text(note.text),
                            trailing: StaleDataChip(fetchedAt: note.fetchedAt),
                          );
                        },
                      ),
              AsyncError(:final error) => Center(
                child: Text('Failed to load notes: $error'),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}
