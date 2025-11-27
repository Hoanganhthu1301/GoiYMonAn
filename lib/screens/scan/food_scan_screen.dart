// lib/screens/scan/food_scan_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../food/food_detail_screen.dart';
import 'package:doan/services/google_vision_service.dart';

class FoodScanScreen extends StatefulWidget {
  const FoodScanScreen({super.key});

  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends State<FoodScanScreen> {
  final GoogleVisionService _vision = GoogleVisionService();

  final ImagePicker _picker = ImagePicker();

  File? _imageFile;
  bool _isScanning = false;
  List<String> _detectedKeywords = [];
  List<DocumentSnapshot> _searchResults = [];
  String? _message;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _detectedKeywords = [];
          _searchResults = [];
          _message = null;
        });
      }
    } catch (e) {
      debugPrint("Lỗi chọn ảnh: $e");
      setState(() => _message = "Không thể chọn ảnh.");
    }
  }

  Future<void> _scanAndSearch() async {
    if (_imageFile == null || _isScanning) return;

    setState(() {
      _isScanning = true;
      _message = "Đang phân tích hình ảnh...";
      _detectedKeywords = [];
      _searchResults = [];
    });

    try {
      final keywords = await _vision.detectLabels(_imageFile!);

      if (keywords.isEmpty) {
        setState(() {
          _message = "Không nhận diện được món ăn nào rõ ràng.";
          _isScanning = false;
        });
        return;
      }

      setState(() {
        _detectedKeywords = keywords;
        _message = "Đang tìm kiếm món ăn phù hợp...";
      });

      debugPrint("Keywords tìm kiếm: $_detectedKeywords");

      // Fetch danh sách món ăn
      final QuerySnapshot allFoodsSnap = await FirebaseFirestore.instance
          .collection('foods')
          .orderBy('created_at', descending: true)
          .limit(80)
          .get();

      List<DocumentSnapshot> matches = [];

      // --- CHẾ ĐỘ LỌC AND ---
      final mainKeys = _detectedKeywords
          .where(
            (k) =>
                k.contains("tomato") ||
                k.contains("cà") ||
                k.contains("ca chua"),
          )
          .toList();

      debugPrint("MAIN KEYS AND = $mainKeys");

      // LỌC CHÍNH XÁC THEO KEYWORDS
      for (var doc in allFoodsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;

        final String name = (data['name'] ?? '').toString().toLowerCase();
        final String ingredients = (data['ingredients'] ?? '')
            .toString()
            .toLowerCase();
        final List<dynamic> dbKeywords = (data['keywords'] ?? [])
            .map((e) => e.toString().toLowerCase())
            .toList();

        bool isMatch = false;

        for (var key in _detectedKeywords) {
          final k = key.toLowerCase();

          // 1. Ưu tiên khớp theo keywords từ database
          if (dbKeywords.contains(k)) {
            isMatch = true;
            break;
          }

          // 2. Khớp theo name hoặc ingredients
          if (name.contains(k) || ingredients.contains(k)) {
            isMatch = true;
            break;
          }
        }

        if (isMatch) {
          matches.add(doc);
        }
      }

      setState(() {
        _searchResults = matches;
        _message = matches.isEmpty
            ? "Đã phân tích, nhưng không tìm thấy món nào khớp."
            : "Tìm thấy ${matches.length} món phù hợp.";
      });
    } catch (e) {
      debugPrint("Lỗi Scan/Search: $e");
      setState(() => _message = "Đã xảy ra lỗi khi xử lý.");
    } finally {
      setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Scan Món Ăn (AI)")),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 300,
              color: Colors.grey.shade200,
              child: _imageFile != null
                  ? Image.file(_imageFile!, fit: BoxFit.contain)
                  : const Center(
                      child: Icon(
                        Icons.image_search,
                        size: 100,
                        color: Colors.grey,
                      ),
                    ),
            ),

            // BUTTONS
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isScanning
                        ? null
                        : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text("Chụp ảnh"),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isScanning
                        ? null
                        : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text("Thư viện"),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: (_imageFile == null || _isScanning)
                    ? null
                    : _scanAndSearch,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(fontSize: 18),
                ),
                child: _isScanning
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("🔍 QUÉT & TÌM KIẾM"),
              ),
            ),

            if (_message != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color:
                        _message!.contains("Không") || _message!.contains("Lỗi")
                        ? Colors.red
                        : Colors.blue,
                  ),
                ),
              ),

            if (_detectedKeywords.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: _detectedKeywords
                      .map(
                        (k) => Chip(
                          label: Text(k),
                          backgroundColor: Colors.orange.shade100,
                        ),
                      )
                      .toList(),
                ),
              ),

            const Divider(),

            if (_searchResults.isNotEmpty)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final doc = _searchResults[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        data['image_url'] ?? '',
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(data['name'] ?? "Món ăn"),
                    subtitle: Text("${data['calories']} kcal"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FoodDetailScreen(foodId: doc.id),
                        ),
                      );
                    },
                  );
                },
              ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
