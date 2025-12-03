import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class GoogleVisionService {
  static const String _apiKey = "AIzaSyCVcGq_f22V-RSAP7rreTu9TrsJbfSiZiY";

  /// Nhận diện label từ ảnh
  Future<List<String>> detectLabels(File imageFile) async {
    final base64Image = base64Encode(await imageFile.readAsBytes());

    final url = "https://vision.googleapis.com/v1/images:annotate?key=$_apiKey";

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

    final res = await http.post(
      Uri.parse(url),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) return [];

    final labels =
        jsonDecode(res.body)["responses"][0]["labelAnnotations"] ?? [];

    return labels.map<String>((l) => l["description"].toString()).toList();
  }
}
