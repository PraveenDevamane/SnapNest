import 'dart:math';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

class FaceClusterService {
  late Interpreter _interpreter;
  final _faceDetector = FaceDetector(
    options: FaceDetectorOptions(performanceMode: FaceDetectorMode.accurate),
  );

  // Each cluster: { clusterId -> [photoUrl, photoUrl, ...] }
  final Map<int, List<String>> _clusters = {};
  final List<List<double>> _centroids = [];

  Future<void> init() async {
    _interpreter = await Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
  }

  // Call this for each photo in the event
  Future<void> processPhoto(String photoUrl, Uint8List imageBytes) async {
    // 1. Detect faces
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/temp_face_img_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(imageBytes);

    final inputImage = InputImage.fromFilePath(file.path);
    final faces = await _faceDetector.processImage(inputImage);
    if (faces.isEmpty) {
      await file.delete();
      return;
    }

    // 2. Crop face + extract embedding
    final decoded = img.decodeImage(imageBytes)!;
    for (final face in faces) {
      final cropped = _cropFace(decoded, face.boundingBox);
      final embedding = _extractEmbedding(cropped);
      
      // 3. Assign to cluster
      final clusterId = _assignCluster(embedding);
      _clusters.putIfAbsent(clusterId, () => []).add(photoUrl);
    }
    await file.delete();
  }

  List<double> _extractEmbedding(img.Image face) {
    // Resize to 112x112
    final resized = img.copyResize(face, width: 112, height: 112);
    
    // Normalize to [-1, 1]
    final input = List.generate(1, (_) =>
      List.generate(112, (y) =>
        List.generate(112, (x) =>
          List.generate(3, (c) {
            final pixel = resized.getPixel(x, y);
            final channels = [pixel.r, pixel.g, pixel.b];
            return (channels[c] - 127.5) / 127.5;
          })
        )
      )
    );

    final output = List.generate(1, (i) => List.filled(128, 0.0));
    _interpreter.run(input, output);
    return List<double>.from((output[0] as List).map((e) => (e as num).toDouble()));
  }

  int _assignCluster(List<double> embedding, {double threshold = 0.4}) {
    if (_centroids.isEmpty) {
      _centroids.add(embedding);
      return 0;
    }

    double minDist = double.infinity;
    int bestCluster = -1;

    for (int i = 0; i < _centroids.length; i++) {
      final dist = _cosineDistance(embedding, _centroids[i]);
      if (dist < minDist) {
        minDist = dist;
        bestCluster = i;
      }
    }

    if (minDist < threshold) {
      // Update centroid (running average)
      _updateCentroid(bestCluster, embedding);
      return bestCluster;
    } else {
      // New person
      _centroids.add(embedding);
      return _centroids.length - 1;
    }
  }

  double _cosineDistance(List<double> a, List<double> b) {
    double dot = 0, normA = 0, normB = 0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    return 1 - (dot / (sqrt(normA) * sqrt(normB)));
  }

  void _updateCentroid(int clusterId, List<double> newEmbedding) {
    for (int i = 0; i < _centroids[clusterId].length; i++) {
      _centroids[clusterId][i] = (_centroids[clusterId][i] + newEmbedding[i]) / 2;
    }
  }

  img.Image _cropFace(img.Image src, Rect bbox) {
    return img.copyCrop(src,
      x: bbox.left.toInt().clamp(0, src.width),
      y: bbox.top.toInt().clamp(0, src.height),
      width: bbox.width.toInt().clamp(1, src.width),
      height: bbox.height.toInt().clamp(1, src.height),
    );
  }

  // Returns clusters for your People row UI
  Map<int, List<String>> get clusters => _clusters;

  void dispose() {
    _interpreter.close();
    _faceDetector.close();
  }
}