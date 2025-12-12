// lib/screens/scan/food_scan_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../food/food_detail_screen.dart';
import 'package:doan/services/google_vision_service.dart';

class FoodScanScreen extends StatefulWidget {
  const FoodScanScreen({super.key});

  @override
  State<FoodScanScreen> createState() => _FoodScanScreenState();
}

class _FoodScanScreenState extends State<FoodScanScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  final ImagePicker _picker = ImagePicker();
  final GoogleVisionService _vision = GoogleVisionService();

  File? _imageFile;
  bool _isScanning = false;
  List<String> _detectedKeywords = [];
  List<DocumentSnapshot> _searchResults = [];
  bool _showResults = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _cameraController = CameraController(cameras.first, ResolutionPreset.high);
      await _cameraController!.initialize();
      if (!mounted) return;
      setState(() => _isCameraInitialized = true);
    } catch (e) {
      debugPrint('Lỗi khởi tạo camera: $e');
    }
  }

  @override
  void dispose() {
    try {
      if (_cameraController != null && _isCameraInitialized) {
        _cameraController!.dispose();
      }
    } catch (e) {
      debugPrint('Lỗi dispose camera: $e');
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _takePhotoAndScan() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isScanning) return;
    try {
      final file = await _cameraController!.takePicture();

      setState(() {
        _imageFile = File(file.path);
        _detectedKeywords = [];
        _searchResults = [];
        _showResults = false;
        _isScanning = true;
      });

      final keywords = await _vision.detectLabels(_imageFile!);

      if (keywords.isEmpty) {
        setState(() {
          _searchResults = [];
          _showResults = true;
          _isScanning = false;
        });
        return;
      }

      setState(() {
        _detectedKeywords = keywords;
      });

      final QuerySnapshot allFoodsSnap = await FirebaseFirestore.instance
          .collection('foods')
          .orderBy('created_at', descending: true)
          .limit(80)
          .get();

      List<DocumentSnapshot> matches = [];

      for (var doc in allFoodsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final ingredients = (data['ingredients'] ?? '').toString().toLowerCase();
        final List<dynamic> dbKeywords = (data['keywords'] ?? [])
            .map((e) => e.toString().toLowerCase())
            .toList();

        bool isMatch = false;
        for (var key in _detectedKeywords) {
          final k = key.toLowerCase();
          if (dbKeywords.contains(k) || name.contains(k) || ingredients.contains(k)) {
            isMatch = true;
            break;
          }
        }

        if (isMatch) matches.add(doc);
      }

      setState(() {
        _searchResults = matches;
        _showResults = true;
        _isScanning = false;
      });
    } catch (e, st) {
      debugPrint("Lỗi chụp/quét: $e\n$st");
      setState(() {
        _isScanning = false;
        _showResults = true;
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _detectedKeywords = [];
          _searchResults = [];
          _showResults = false;
        });
        await _scanAndSearchFromFile();
      }
    } catch (e) {
      debugPrint("Lỗi chọn ảnh: $e");
    }
  }

  Future<void> _scanAndSearchFromFile() async {
    if (_imageFile == null) return;

    setState(() => _isScanning = true);

    try {
      final keywords = await _vision.detectLabels(_imageFile!);

      if (keywords.isEmpty) {
        setState(() {
          _searchResults = [];
          _showResults = true;
          _isScanning = false;
        });
        return;
      }

      setState(() {
        _detectedKeywords = keywords;
      });

      final QuerySnapshot allFoodsSnap = await FirebaseFirestore.instance
          .collection('foods')
          .orderBy('created_at', descending: true)
          .limit(80)
          .get();

      List<DocumentSnapshot> matches = [];

      for (var doc in allFoodsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = (data['name'] ?? '').toString().toLowerCase();
        final ingredients = (data['ingredients'] ?? '').toString().toLowerCase();
        final List<dynamic> dbKeywords = (data['keywords'] ?? [])
            .map((e) => e.toString().toLowerCase())
            .toList();

        bool isMatch = false;
        for (var key in _detectedKeywords) {
          final k = key.toLowerCase();
          if (dbKeywords.contains(k) || name.contains(k) || ingredients.contains(k)) {
            isMatch = true;
            break;
          }
        }

        if (isMatch) matches.add(doc);
      }

      setState(() {
        _searchResults = matches;
        _showResults = true;
        _isScanning = false;
      });
    } catch (e, st) {
      debugPrint('Lỗi khi quét ảnh từ file: $e\n$st');
      setState(() {
        _isScanning = false;
        _showResults = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Nếu đã chụp ảnh thì hiển thị ảnh, nếu chưa thì live camera
          Positioned.fill(
            child: _imageFile != null
                ? Image.file(_imageFile!, fit: BoxFit.cover)
                : (_isCameraInitialized && _cameraController != null
                    ? CameraPreview(_cameraController!)
                    : const Center(child: CircularProgressIndicator())),
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Nút chụp & scan
          if (_imageFile == null)
            Positioned(
              bottom: 16,
              left: 16,
              child: FloatingActionButton(
                onPressed: _takePhotoAndScan,
                backgroundColor: const Color(0xFF1B8E7B),
                child: _isScanning
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.camera_alt),
              ),
            ),

          // Nút gallery
          if (_imageFile == null)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: _pickImageFromGallery,
                backgroundColor: const Color(0xFF1B8E7B),
                child: const Icon(Icons.photo_library),
              ),
            ),

          // Panel kết quả trượt từ dưới lên
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
            bottom: _showResults ? 0 : -400,
            left: 0,
            right: 0,
            height: 400,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Expanded(
                    child: _searchResults.isNotEmpty
                        ? ListView.builder(
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
                                    errorBuilder: (c, e, s) => const SizedBox.shrink(),
                                  ),
                                ),
                                title: Text(data['name'] ?? "Món ăn"),
                                subtitle: Text("${data['calories'] ?? '-'} kcal"),
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
                          )
                        : Center(
                            child: Text(
                              _isScanning ? "Đang phân tích..." : "Không tìm thấy món nào",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
