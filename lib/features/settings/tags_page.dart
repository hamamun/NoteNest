import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/icons.dart';
import '../../app/services.dart';
import '../../data/db/database.dart';

/// V2: tag management.
class TagsPage extends StatelessWidget {
  const TagsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final services = context.read<Services>();

    return Scaffold(
      appBar: AppBar(
        leading: AppIconButton(
          icon: AppIcons.back,
          label: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Tags'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createTag(context),
        tooltip: 'New tag',
        child: const Icon(AppIcons.newItem),
      ),
      body: StreamBuilder<List<Tag>>(
        stream: services.entries.watchTags(),
        builder: (context, snapshot) {
          final tags = snapshot.data ?? const <Tag>[];
          if (tags.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No tags yet.\nTags help you group notes across Home and '
                  'Archive.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: tags.length,
            itemBuilder: (context, index) {
              final tag = tags[index];
              return ListTile(
                leading: const Icon(AppIcons.tag),
                title: Text(tag.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIconButton(
                      icon: AppIcons.edit,
                      label: 'Rename tag',
                      onPressed: () => _renameTag(context, tag),
                    ),
                    AppIconButton(
                      icon: AppIcons.trash,
                      label: 'Delete tag',
                      onPressed: () => _deleteTag(context, tag),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _createTag(BuildContext context) async {
    final name = await _promptName(context, title: 'New tag');
    if (name == null || name.isEmpty || !context.mounted) return;
    await context.read<Services>().entries.createTag(name);
  }

  Future<void> _renameTag(BuildContext context, Tag tag) async {
    final name = await _promptName(
      context,
      title: 'Rename tag',
      initial: tag.name,
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await context.read<Services>().entries.renameTag(tag.id, name);
  }

  Future<void> _deleteTag(BuildContext context, Tag tag) async {
    final confirmed = await confirmDestructive(
      context,
      title: 'Delete tag?',
      message: '"${tag.name}" will be removed from every note. '
          'The notes themselves are not deleted.',
      confirmLabel: 'Delete tag',
    );
    if (!confirmed || !context.mounted) return;
    await context.read<Services>().entries.deleteTag(tag.id);
  }

  Future<String?> _promptName(
    BuildContext context, {
    required String title,
    String initial = '',
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tag name'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
