import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

class TFLiteService {
  static bool _isInitialized = false;

  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Simulate TFLite initialization for web compatibility
      // In a real mobile app, you would load the actual TFLite model
      _isInitialized = true;
      print('TFLite service initialized (simulated for web)');
    } catch (e) {
      print('Error initializing TFLite: $e');
      _isInitialized = false;
    }
  }

  static Future<List<double>> generateFaceEmbedding(String imagePath) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // For web compatibility, we'll generate a simulated embedding
      // In a real mobile app, you would process the actual image
      return _generateSimulatedEmbedding();
      
    } catch (e) {
      print('Error generating face embedding: $e');
      // Return a simulated embedding for demo purposes
      return _generateSimulatedEmbedding();
    }
  }

  static List<double> _generateSimulatedEmbedding() {
    // Generate a simulated 512-dimensional embedding
    // In a real app, this would come from the TFLite model
    final random = math.Random();
    final embedding = List.generate(512, (index) => random.nextDouble() * 2 - 1);
    
    // Normalize the embedding
    final norm = embedding.map((e) => e * e).reduce((a, b) => a + b);
    final normalizedNorm = math.sqrt(norm);
    
    return embedding.map((e) => e / normalizedNorm).toList();
  }

  static String embeddingToString(List<double> embedding) {
    return embedding.map((e) => e.toString()).join(',');
  }

  static List<double> stringToEmbedding(String embeddingString) {
    return embeddingString
        .split(',')
        .map((e) => double.tryParse(e) ?? 0.0)
        .toList();
  }

  static Future<void> dispose() async {
    _isInitialized = false;
  }
}