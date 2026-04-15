import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer _textRecognizer = TextRecognizer();
  
  Future<String> extractTextFromImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      final StringBuffer extractedText = StringBuffer();
      
      for (TextBlock block in recognizedText.blocks) {
        for (TextLine line in block.lines) {
          extractedText.writeln(line.text);
        }
      }
      
      return extractedText.toString().trim();
    } catch (e) {
      throw Exception('Failed to extract text: $e');
    }
  }
  
  void dispose() {
    _textRecognizer.close();
  }
}
