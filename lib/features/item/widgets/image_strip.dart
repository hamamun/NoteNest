import 'dart:io';

import 'package:flutter/material.dart';

import '../../../app/icons.dart';
import '../../../data/db/database.dart';

/// IMG-07/IMG-12: the image strip shown inside an open note or list.
class ImageStrip extends StatelessWidget {
  const ImageStrip({
    super.key,
    required this.images,
    required this.editing,
    required this.onDelete,
  });

  final List<EntryImage> images;
  final bool editing;
  final void Function(EntryImage image) onDelete;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: images.map((image) => _tile(context, image)).toList(),
      ),
    );
  }

  Widget _tile(BuildContext context, EntryImage image) {
    final file = File(image.localPath);
    if (!file.existsSync()) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => _openViewer(context, image),
            child: Image.file(
              file,
              width: 150,
              height: 150,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 150,
                height: 150,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(AppIcons.image),
              ),
            ),
          ),
        ),
        if (editing)
          Positioned(
            top: 2,
            right: 2,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: AppIconButton(
                icon: AppIcons.clear,
                label: 'Remove image',
                iconSize: 16,
                color: Colors.white,
                onPressed: () => onDelete(image),
              ),
            ),
          ),
      ],
    );
  }

  void _openViewer(BuildContext context, EntryImage image) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (viewerContext) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(image.fileName, style: const TextStyle(fontSize: 14)),
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: Image.file(File(image.localPath)),
            ),
          ),
        ),
      ),
    );
  }
}
