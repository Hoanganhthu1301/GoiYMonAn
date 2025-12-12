import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GoogleVisionService {
  final String apiKey = "AIzaSyCVcGq_f22V-RSAP7rreTu9TrsJbfSiZiY";

  Future<List<String>> detectLabels(File image) async {
    final bytes = await image.readAsBytes();
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

    final data = jsonDecode(response.body);

    final labels = data["responses"][0]["labelAnnotations"];

    if (labels == null) return [];

    return labels
        .map<String>((e) => e["description"].toString().toLowerCase())
        .toList();
  }
}
