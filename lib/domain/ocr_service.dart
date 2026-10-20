import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// OCR on-device (ML Kit) - chạy hoàn toàn offline.
class OcrService {
  final TextRecognizer _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Trả về chuỗi rỗng nếu không đọc được chữ nào.
  Future<String> recognize(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    return result.text.trim();
  }

  Future<void> dispose() => _recognizer.close();
}
