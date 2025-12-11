// lib/services/gemini_service.dart
// ignore_for_file: avoid_print
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../config/app_config.dart';

class GeminiService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton cho tiện dùng
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;

  GeminiService._internal() {
    print('🔥 GeminiService init với REST API');
  }

  /// Gọi ListModels để lấy danh sách model khả dụng (không cần body)
  /// Trả về danh sách tên model (ví dụ: `models/text-bison-001`)
  Future<List<String>> listModels() async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models'
      '?key=${AppConfig.geminiApiKey}',
    );

    try {
      final resp = await http.get(url, headers: {'Content-Type': 'application/json'});
      if (resp.statusCode == 200) {
        final jr = jsonDecode(resp.body);
        final List<String> models = [];

        if (jr is Map<String, dynamic>) {
          // Newer responses may include 'models' array or 'modelSummaries'
          if (jr['models'] is List) {
            for (var m in jr['models']) {
              if (m is Map && m['name'] != null) models.add(m['name'].toString());
            }
          }
          if (jr['modelSummaries'] is List) {
            for (var m in jr['modelSummaries']) {
              if (m is Map && m['name'] != null) models.add(m['name'].toString());
            }
          }
        }

        return models;
      } else {
        print('❌ ListModels failed: ${resp.statusCode}');
        print('Response: ${resp.body}');
        return [];
      }
    } catch (e) {
      print('❌ Lỗi gọi ListModels: $e');
      return [];
    }
  }

  /// Gọi Gemini API trực tiếp qua REST
  Future<String> _callGeminiAPI(String prompt) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent'
        '?key=${AppConfig.geminiApiKey}',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          // Removed invalid safetySettings field (caused 400 INVALID_ARGUMENT)
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 2048,
          }
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final text = jsonResponse['candidates']?[0]?['content']?['parts']?[0]?['text'];
        return text ?? 'AI chưa trả lời được, bạn thử hỏi lại câu khác đơn giản hơn nha.';
      } else if (response.statusCode == 404) {
        // Model not found / unsupported for this method. Try to list available models
        print('❌ Gemini API 404: model not found or not supported for generateContent');
        print('Response: ${response.body}');

        // Try to recover automatically (debug-friendly): list available models
        try {
          final available = await listModels();
          if (available.isNotEmpty) {
            print('✅ Models available from ListModels:');
            for (var m in available) print(' - $m');

            // Choose a fallback model heuristically: prefer non-embedding text/chat models
            String? fallback;
            for (var m in available) {
              final lower = m.toLowerCase();
              if (lower.contains('embedding')) continue;
              if (lower.contains('text') || lower.contains('chat') || lower.contains('gemini')) {
                fallback = m;
                break;
              }
            }

            if (fallback != null) {
              print('🔁 Attempting fallback with model: $fallback');
              try {
                final apiKey = AppConfig.geminiApiKey;
                final fallbackUrl = Uri.parse(
                  'https://generativelanguage.googleapis.com/v1beta/$fallback:generateContent?key=$apiKey',
                );
                final fallbackResp = await http.post(
                  fallbackUrl,
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'contents': [
                      {
                        'parts': [
                          {'text': prompt}
                        ]
                      }
                    ],
                    'generationConfig': {
                      'temperature': 0.7,
                      'maxOutputTokens': 2048,
                    }
                  }),
                );

                print('Fallback response code: ${fallbackResp.statusCode}');
                if (fallbackResp.statusCode == 200) {
                  final jr = jsonDecode(fallbackResp.body);
                  print('📋 Fallback response body: ${fallbackResp.body}');
                  final text = jr['candidates']?[0]?['content']?['parts']?[0]?['text'];
                  print('📝 Extracted text: $text');
                  if (text != null) return text as String;
                  print('⚠️ Text was null or empty after parsing');
                } else {
                  print('Fallback failed: ${fallbackResp.body}');
                }
              } catch (e) {
                print('⚠️ Fallback call failed: $e');
              }
            } else {
              print('⚠️ Không tìm thấy model fallback hợp lệ trong danh sách.');
            }
          } else {
            print('⚠️ ListModels returned no models or failed.');
          }
        } catch (e) {
          print('⚠️ Failed to call ListModels: $e');
        }

        // If automatic fallback did not succeed, return original helpful message
        return 'Xin lỗi, model hiện tại không được hỗ trợ cho API này.\n' 
            'Mình đã gọi ListModels và ghi ra console các model có sẵn — xem log để biết tên model hợp lệ.\n' 
            'Khi bạn có tên model hợp lệ, cập nhật đường dẫn model trong `lib/services/gemini_service.dart` (biến url) và thử lại.';
      } else {
        print('❌ Gemini API error: ${response.statusCode}');
        print('Response: ${response.body}');
        return 'Xin lỗi, AI đang gặp lỗi: ${response.statusCode}\n\nBạn thử lại sau nha 🥲';
      }
    } catch (e) {
      print('❌ Lỗi gọi Gemini: $e');
      print('🔍 Chi tiết: ${e.toString()}');
      return 'Xin lỗi, AI đang gặp lỗi: ${e.toString()}\n\nBạn thử lại sau nha 🥲';
    }
  }

  /// HÀM CHÍNH:
  /// Câu hỏi bất kỳ về món ăn / chế độ ăn / cân nặng → trả lời dựa trên data Firebase.
  Future<String> askNutrition(String question) async {
    try {
      // 1. Lấy user hiện tại (nếu chưa login thì trả lời chung chung)
      final user = _auth.currentUser;
      Map<String, dynamic>? userData;
      if (user != null) {
        final snap = await _db.collection('users').doc(user.uid).get();
        userData = snap.data();
      }

      // 2. Lấy danh sách category (loại món ăn) từ collection "categories"
      final catSnap = await _db.collection('categories').get();
      final categoriesText = catSnap.docs.map((doc) {
        final data = doc.data();
        final name = data['name'] ?? 'Không tên';
        final type = data['type'] ?? '';
        return '- $name (type: $type)';
      }).join('\n');

      // 3. Lấy 1 danh sách món ăn từ collection "foods"
      final foodSnap = await _db
          .collection('foods')
          .limit(80) // giới hạn để prompt không quá dài
          .get();

      final foodsText = foodSnap.docs.map((doc) {
        final data = doc.data();

        final name =
            data['name'] ?? data['foodName'] ?? data['title'] ?? 'Không tên';
        final calories =
            data['calories'] ?? data['calo'] ?? data['kcal'] ?? 'n/a';
        final category = data['categoryName'] ??
            data['category'] ??
            data['category_id'] ??
            '';
        final dietType = data['dietType'] ?? data['diet'] ?? data['mode'] ?? '';

        return '- $name | $calories kcal | category: $category | diet: $dietType';
      }).join('\n');

      // 4. Build prompt gửi cho Gemini
      final prompt = StringBuffer();

      prompt.writeln(
        'Bạn là trợ lý dinh dưỡng của một ứng dụng tính calo & gợi ý món ăn.',
      );
      prompt.writeln(
        'Nhiệm vụ: tư vấn chế độ ăn, món ăn, giảm/tăng cân dựa trên dữ liệu trong app.',
      );
      prompt.writeln(
        'Luôn trả lời bằng TIẾNG VIỆT, giọng thân thiện, dễ hiểu, không dùng từ quá chuyên môn.',
      );

      // THÔNG TIN USER
      prompt.writeln('\n--- THÔNG TIN NGƯỜI DÙNG (TỪ COLLECTION users) ---');
      if (userData != null) {
        final name = userData['name'] ?? 'người dùng';
        final gender = userData['gender'] ?? 'không rõ';
        final age = userData['age'] ?? 'không rõ';
        final height = userData['height'] ?? 'không rõ'; // cm
        final weight = userData['weight'] ?? 'không rõ'; // kg
        final goal = userData['goal'] ?? 'không rõ'; // ví dụ: "giảm cân"
        final tdee = userData['tdee'] ?? userData['TDEE'] ?? '';
        final todayCalories =
            userData['todayCalories'] ?? userData['today_calo'] ?? '';

        prompt.writeln('Tên: $name');
        prompt.writeln('Giới tính: $gender');
        prompt.writeln('Tuổi: $age');
        prompt.writeln('Chiều cao: $height cm');
        prompt.writeln('Cân nặng: $weight kg');
        prompt.writeln('Mục tiêu: $goal');
        if (tdee.toString().isNotEmpty) {
          prompt.writeln('TDEE ước tính: $tdee kcal/ngày');
        }
        if (todayCalories.toString().isNotEmpty) {
          prompt.writeln('Calo đã ăn hôm nay: $todayCalories kcal');
        }
      } else {
        prompt.writeln(
            'Chưa đăng nhập, không có dữ liệu cá nhân. Hãy tư vấn ở mức tổng quát.');
      }

      // CATEGORY
      prompt.writeln('\n--- CÁC LOẠI MÓN ĂN (COLLECTION categories) ---');
      if (categoriesText.isEmpty) {
        prompt.writeln('Không có category nào.');
      } else {
        prompt.writeln(categoriesText);
      }

      // FOODS
      prompt.writeln(
          '\n--- DANH SÁCH MÓN ĂN TRONG ỨNG DỤNG (COLLECTION foods) ---');
      if (foodsText.isEmpty) {
        prompt.writeln('Hiện chưa có món ăn nào trong hệ thống.');
      } else {
        prompt.writeln(foodsText);
      }

      // CÂU HỎI
      prompt.writeln('\n--- CÂU HỎI CỦA NGƯỜI DÙNG ---');
      prompt.writeln(question);

      // HƯỚNG DẪN TRẢ LỜI
      prompt.writeln('\n--- YÊU CẦU TRẢ LỜI ---');
      prompt.writeln(
        '- CHỦY ẾU sử dụng dữ liệu từ app (danh sách món ăn, category, thông tin user) để trả lời.\n'
        '- Nếu câu hỏi CÓ liên quan đến dữ liệu app, hãy ưu tiên gợi ý các món ăn / category có trong hệ thống.\n'
        '- Bạn CÓ THỂ bổ sung một ít kiến thức chung (ví dụ: lợi ích dinh dưỡng, cách tính calo) để giải thích thêm, nhưng không phải là trọng tâm.\n'
        '- Nếu câu hỏi KHÔNG thể trả lời dựa chủ yếu trên dữ liệu app, hãy nói: "Xin lỗi, mình chủ yếu tư vấn dựa trên dữ liệu trong hệ thống."\n'
        '- Trả lời bằng TIẾNG VIỆT, giọng thân thiện, dễ hiểu.\n',
      );

      return await _callGeminiAPI(prompt.toString());
    } catch (e) {
      print('❌ Lỗi askNutrition: $e');
      return 'Xin lỗi, AI đang gặp lỗi: ${e.toString()}\n\nBạn thử lại sau nha 🥲';
    }
  }

  /// Chat đơn giản, không gắn Firebase (phòng khi cần)
  Future<String> simpleChat(String message) async {
    final prompt =
        'Bạn là trợ lý dinh dưỡng, trả lời bằng tiếng Việt, ngắn gọn, thân thiện.\n'
        'Câu hỏi: $message';
    return await _callGeminiAPI(prompt);
  }
}
