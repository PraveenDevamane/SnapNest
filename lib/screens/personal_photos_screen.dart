import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../core/constants.dart';
import '../widgets/custom_widgets.dart';
import 'photo_view_screen.dart';
import '../models/photo_metadata.dart';

class PersonalPhotosScreen extends StatefulWidget {
  const PersonalPhotosScreen({super.key});

  @override
  State<PersonalPhotosScreen> createState() => _PersonalPhotosScreenState();
}

class _PersonalPhotosScreenState extends State<PersonalPhotosScreen> {
  List<File> _localPhotos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocalPhotos();
  }

  Future<void> _loadLocalPhotos() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final photosDir = Directory('${directory.path}/photos');

      if (await photosDir.exists()) {
        final files = await photosDir
            .list()
            .where((entity) => entity is File && entity.path.endsWith('.jpg'))
            .cast<File>()
            .toList();

        // Sort by modified date, newest first
        files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified),
        );

        setState(() {
          _localPhotos = files;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Photos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _localPhotos.isEmpty
          ? const EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No local photos',
              subtitle: 'Photos you capture will appear here',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(AppConfig.photoGridSpacing),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: AppConfig.photoGridColumns,
                crossAxisSpacing: AppConfig.photoGridSpacing,
                mainAxisSpacing: AppConfig.photoGridSpacing,
              ),
              itemCount: _localPhotos.length,
              itemBuilder: (context, index) {
                final file = _localPhotos[index];
                final heroTag = 'local_photo_$index';

                // Convert all local files to PhotoMetadata list for swipe support
                final allPhotos = _localPhotos
                    .map(
                      (f) => PhotoMetadata(
                        id: 'local_${_localPhotos.indexOf(f)}',
                        eventId: '',
                        folderId: '',
                        ownerId: '',
                        localPath: f.path,
                        uploadStatus: PhotoUploadStatus.completed,
                        storageType: PhotoStorageType.localOnly,
                      ),
                    )
                    .toList();

                return GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PhotoViewScreen(
                          photos: allPhotos,
                          initialIndex: index,
                          heroTag: heroTag,
                        ),
                      ),
                    );
                  },
                  child: Hero(
                    tag: heroTag,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.cardBackground,
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
