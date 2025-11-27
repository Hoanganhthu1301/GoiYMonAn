import 'dart:convert';
import 'package:http/http.dart' as http;

class IngredientKeywordService {
  final String apiKey = "AIzaSyDASNw36gzrCaPCm9tlD0zSx7h6MuAbkNA";

  // Bỏ dấu tiếng Việt
  String removeDiacritics(String str) {
    const vietnamese =
        'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễ'
        'ìíịỉĩòóọỏõôồốộổỗơờớợởỡ'
        'ùúụủũưừứựửữỳýỵỷỹđ'
        'ÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴ'
        'ÈÉẸẺẼÊỀẾỆỂỄ'
        'ÌÍỊỈĨ'
        'ÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠ'
        'ÙÚỤỦŨƯỪỨỰỬỮ'
        'ỲÝỴỶỸĐ';

    const latin =
        'aaaaaaaaaaaaaaaaaeeeeeeeeeee'
        'iiiii'
        'ooooooooooooooooo'
        'uuuuuuuuuuu'
        'yyyyyd'
        'AAAAAAAAAAAAAAAAAEEEEEEEEEEE'
        'IIIII'
        'OOOOOOOOOOOOOOOOO'
        'UUUUUUUUUUU'
        'YYYYYD';

    for (int i = 0; i < vietnamese.length; i++) {
      str = str.replaceAll(vietnamese[i], latin[i]);
    }
    return str;
  }

  // Gọi Google Translate API
  Future<String> translateToEnglish(String text) async {
    final url =
        "https://translation.googleapis.com/language/translate/v2?key=$apiKey";

    final response = await http.post(
      Uri.parse(url),
      body: {"q": text, "target": "en", "source": "vi"},
    );

    final data = json.decode(response.body);
    return data["data"]["translations"][0]["translatedText"];
  }

  // Tạo keywords từ nguyên liệu + dịch tự động
  Future<List<String>> generateKeywords(String input) async {
    final keywords = <String>{};

    // Tách từng dòng
    final lines = input.toLowerCase().split(RegExp(r"[,;\n]"));

    for (var line in lines) {
      String clean = line.trim();
      if (clean.isEmpty) continue;

      // Bỏ từ rác
      const stopWords = {
        "quả",
        "củ",
        "trái",
        "con",
        "g",
        "kg",
        "ml",
        "gr",
        "gia",
        "vị",
        "hoặc",
        "nếu",
        "có",
        "1/2",
        "1",
        "2",
        "3",
        "4",
      };

      final words = clean.split(" ");
      words.removeWhere((w) => stopWords.contains(w));

      clean = words.join(" ").trim();
      if (clean.isEmpty) continue;

      // 1. Thêm tiếng Việt
      keywords.add(clean);
      keywords.add(removeDiacritics(clean));

      // 2. Dịch sang tiếng Anh
      final en = await translateToEnglish(clean);
      keywords.add(en.toLowerCase());
    }

    return keywords.toList();
  }
}
