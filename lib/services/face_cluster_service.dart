import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceClusterService {
  static const double _centroidMatchThreshold = 0.32;
  static const double _memberMatchThreshold = 0.40;
  static const int _maxEmbeddingsPerCluster = 25;
  static const int _minFaceSizeInPixels = 48;
  static const double _faceCropMarginRatio = 0.20;

  late Interpreter _interpreter;
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );

  // Each cluster: { clusterId -> [photoUrl, photoUrl, ...] }
  final Map<int, List<String>> _clusters = {};
  final List<List<double>> _centroids = [];
  final List<int> _clusterCounts = [];
  final List<List<List<double>>> _clusterEmbeddings = [];

  Future<void> init() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/mobilefacenet.tflite',
    );
  }

  // Call this for each photo in the event
  Future<void> processPhoto(String photoUrl, Uint8List imageBytes) async {
    // 1. Detect faces
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/temp_face_img_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(imageBytes);

    final inputImage = InputImage.fromFilePath(file.path);
    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isEmpty) {
      await file.delete();
      return;
    }

    // 2. Crop face + extract embedding
    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) {
      await file.delete();
      return;
    }

    for (final face in faces) {
      if (!_isFaceLargeEnough(face.boundingBox)) continue;

      final cropped = _cropFace(decoded, face.boundingBox);
      final embedding = _extractEmbedding(cropped);

      // 3. Assign to cluster
      final clusterId = _assignCluster(embedding);
      final clusterPhotos = _clusters.putIfAbsent(clusterId, () => []);
      if (!clusterPhotos.contains(photoUrl)) {
        clusterPhotos.add(photoUrl);
      }
    }
    await file.delete();
  }

  List<double> _extractEmbedding(img.Image face) {
    // Resize to 112x112
    final resized = img.copyResize(face, width: 112, height: 112);

    // Normalize to [-1, 1]
    final input = List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(
          112,
          (x) => List.generate(3, (c) {
            final pixel = resized.getPixel(x, y);
            final channels = [pixel.r, pixel.g, pixel.b];
            return (channels[c] - 127.5) / 127.5;
          }),
        ),
      ),
    );

    final output = List.generate(1, (i) => List.filled(128, 0.0));
    _interpreter.run(input, output);
    final raw = List<double>.from(
      (output[0] as List).map((e) => (e as num).toDouble()),
    );
    return _l2Normalize(raw);
  }

  int _assignCluster(List<double> embedding) {
    if (_centroids.isEmpty) {
      _createCluster(embedding);
      return 0;
    }

    double bestCentroidDist = double.infinity;
    int bestCluster = -1;

    for (int i = 0; i < _centroids.length; i++) {
      final dist = _cosineDistance(embedding, _centroids[i]);
      if (dist < bestCentroidDist) {
        bestCentroidDist = dist;
        bestCluster = i;
      }
    }

    if (bestCentroidDist <= _centroidMatchThreshold && bestCluster >= 0) {
      final bestMemberDist = _minDistanceToClusterMembers(
        embedding,
        bestCluster,
      );
      if (bestMemberDist <= _memberMatchThreshold) {
        _updateCluster(bestCluster, embedding);
        return bestCluster;
      }
    }

    _createCluster(embedding);
    return _centroids.length - 1;
  }

  void _createCluster(List<double> embedding) {
    final normalized = _l2Normalize(embedding);
    _centroids.add(List<double>.from(normalized));
    _clusterCounts.add(1);
    _clusterEmbeddings.add([List<double>.from(normalized)]);
  }

  double _minDistanceToClusterMembers(List<double> embedding, int clusterId) {
    final members = _clusterEmbeddings[clusterId];
    var minDist = double.infinity;
    for (final member in members) {
      final dist = _cosineDistance(embedding, member);
      if (dist < minDist) {
        minDist = dist;
      }
    }
    return minDist;
  }

  double _cosineDistance(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denominator = sqrt(normA) * sqrt(normB);
    if (denominator == 0) return 1.0;

    final similarity = dot / denominator;
    final boundedSimilarity = similarity.clamp(-1.0, 1.0).toDouble();
    return 1 - boundedSimilarity;
  }

  void _updateCluster(int clusterId, List<double> newEmbedding) {
    final count = _clusterCounts[clusterId];
    final centroid = _centroids[clusterId];
    for (int i = 0; i < centroid.length; i++) {
      centroid[i] = ((centroid[i] * count) + newEmbedding[i]) / (count + 1);
    }
    _centroids[clusterId] = _l2Normalize(centroid);
    _clusterCounts[clusterId] = count + 1;

    final embeddings = _clusterEmbeddings[clusterId];
    if (embeddings.length >= _maxEmbeddingsPerCluster) {
      embeddings.removeAt(0);
    }
    embeddings.add(List<double>.from(newEmbedding));
  }

  List<double> _l2Normalize(List<double> vector) {
    var normSquared = 0.0;
    for (final value in vector) {
      normSquared += value * value;
    }

    final norm = sqrt(normSquared);
    if (norm == 0) {
      return List<double>.from(vector);
    }

    return vector.map((value) => value / norm).toList(growable: false);
  }

  bool _isFaceLargeEnough(Rect bbox) {
    return bbox.width >= _minFaceSizeInPixels &&
        bbox.height >= _minFaceSizeInPixels;
  }

  img.Image _cropFace(img.Image src, Rect bbox) {
    final marginX = bbox.width * _faceCropMarginRatio;
    final marginY = bbox.height * _faceCropMarginRatio;

    final left = max(0, (bbox.left - marginX).floor());
    final top = max(0, (bbox.top - marginY).floor());
    final right = min(src.width, (bbox.right + marginX).ceil());
    final bottom = min(src.height, (bbox.bottom + marginY).ceil());

    final cropWidth = max(1, right - left);
    final cropHeight = max(1, bottom - top);

    return img.copyCrop(
      src,
      x: left,
      y: top,
      width: cropWidth,
      height: cropHeight,
    );
  }

  // Returns clusters for your People row UI
  Map<int, List<String>> get clusters => _clusters;

  void reset() {
    _clusters.clear();
    _centroids.clear();
    _clusterCounts.clear();
    _clusterEmbeddings.clear();
  }

  void dispose() {
    _interpreter.close();
    _faceDetector.close();
  }
}
