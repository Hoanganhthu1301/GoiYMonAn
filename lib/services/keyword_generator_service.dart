// lib/services/keyword_generator_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class KeywordGeneratorService {
  final String apiKey = "AIzaSyCVcGq_f22V-RSAP7rreTu9TrsJbfSiZiY";

  Future<List<String>> generateKeywords(File file) async {
    final bytes = await file.readAsBytes();
    final base64Image = base64Encode(bytes);

    final url = "https://vision.googleapis.com/v1/images:annotate?key=$apiKey";

    final body = {
      "requests": [
        {
          "image": {"content": base64Image},
          "features": [
            {"type": "LABEL_DETECTION", "maxResults": 10},
          ],
        },
      ],
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) return [];

    final data = jsonDecode(response.body);
    final labels = data["responses"][0]["labelAnnotations"];

    final keywords = <String>{};

    for (var label in labels) {
      final text = label["description"].toString().toLowerCase();
      keywords.add(text);
    }

    return keywords.toList();
  }
}
