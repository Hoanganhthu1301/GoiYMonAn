import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import 'package:image_picker/image_picker.dart';
import '../../services/google_vision_service.dart';
import '../../services/foods_database.dart';
import '../../services/intake_service.dart';
import '../../services/auth_service.dart';

class CalorieScanScreen extends StatefulWidget {
  const CalorieScanScreen({super.key});

  @override
  State<CalorieScanScreen> createState() => _CalorieScanScreenState();
}

class _CalorieScanScreenState extends State<CalorieScanScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late CameraController _cameraController;
  final ImagePicker _picker = ImagePicker();
  final GoogleVisionService _vision = GoogleVisionService();

  bool _isCameraInitialized = false;
  bool _isScanning = false;
  File? _capturedImage;

  List<Map<String, dynamic>> detectedFoods = [];
  bool _showResults = false;

  // Animation line scan
  late AnimationController _lineController;
  late Animation<double> _lineAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();

    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _lineAnimation = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
      parent: _lineController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) return;
    _cameraController = CameraController(cameras.first, ResolutionPreset.max, enableAudio: false);
    await _cameraController.initialize();
    if (!mounted) return;
    setState(() => _isCameraInitialized = true);
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _lineController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _captureAndScan() async {
    if (!_cameraController.value.isInitialized || _isScanning) return;

    try {
      final file = await _cameraController.takePicture();
      setState(() {
        _capturedImage = File(file.path);
        detectedFoods.clear();
        _showResults = false;
        _isScanning = true;
      });

      await _scanImage(_capturedImage!);
    } catch (e) {
      debugPrint("Lỗi chụp ảnh: $e");
      setState(() => _isScanning = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _capturedImage = File(pickedFile.path);
        detectedFoods.clear();
        _showResults = false;
        _isScanning = true;
      });
      await _scanImage(_capturedImage!);
    }
  }

  Future<void> _scanImage(File image) async {
    try {
      final labels = await _vision.detectLabels(image);
      List<Map<String, dynamic>> results = [];

      for (var label in labels) {
        final l = label.toLowerCase();
        for (var food in foodDB) {
          if (l.contains(food["keyword"])) {
            results.add({
              "name": food["name"],
              "grams": 100,
              "cal_per_100g": food["cal"],
            });
          }
        }
      }

      setState(() {
        detectedFoods = results;
        _showResults = true;
      });
    } catch (e) {
      debugPrint("Lỗi scan: $e");
    } finally {
      setState(() => _isScanning = false);
    }
  }

  double get totalCal {
    double total = 0;
    for (var f in detectedFoods) {
      total += f["grams"] / 100 * f["cal_per_100g"];
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isCameraInitialized
          ? Stack(
              children: [
                // Fullscreen camera
                Positioned.fill(
                  child: _capturedImage == null
                      ? CameraPreview(_cameraController)
                      : Image.file(_capturedImage!, fit: BoxFit.cover),
                ),

                // Line scan animation khi đang scan
                if (_isScanning)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _lineAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _LineScanPainter(_lineAnimation.value),
                        );
                      },
                    ),
                  ),

                // Nút chụp
                Positioned(
                  bottom: 20,
                  left: 30,
                  child: FloatingActionButton(
                    onPressed: _captureAndScan,
                    backgroundColor: Colors.orange,
                    child: _isScanning
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Icon(Icons.camera_alt),
                  ),
                ),

                // Nút gallery
                Positioned(
                  bottom: 20,
                  right: 30,
                  child: FloatingActionButton(
                    onPressed: _pickFromGallery,
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.photo_library),
                  ),
                ),

                // Kết quả slide-up
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  bottom: _showResults ? 0 : -400,
                  left: 0,
                  right: 0,
                  height: 400,
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      if (details.delta.dy > 0) {
                        // kéo xuống để ẩn
                        setState(() => _showResults = false);
                      }
                    },
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
                      child: SingleChildScrollView(
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
                            if (_capturedImage != null)
                              SizedBox(
                                height: 200,
                                child: Image.file(_capturedImage!, fit: BoxFit.cover),
                              ),
                            const SizedBox(height: 10),
                            if (_isScanning) const CircularProgressIndicator(),
                            ...detectedFoods.map((food) {
                              return ListTile(
                                title: Text(food["name"]),
                                subtitle: Row(
                                  children: [
                                    const Text("Gram: "),
                                    SizedBox(
                                      width: 60,
                                      child: TextField(
                                        keyboardType: TextInputType.number,
                                        onChanged: (v) {
                                          setState(() {
                                            food["grams"] = double.tryParse(v) ?? 100;
                                          });
                                        },
                                        controller: TextEditingController(
                                          text: food["grams"].toString(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      "${(food['grams'] / 100 * food['cal_per_100g']).round()} kcal",
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() => detectedFoods.remove(food));
                                  },
                                ),
                              );
                            }).toList(),
                            const SizedBox(height: 10),
                            Text(
                              "Tổng: ${totalCal.round()} kcal",
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 10),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: () async {
                                final uid = AuthService().currentUser?.uid;
                                if (uid == null) return;

                                for (var f in detectedFoods) {
                                  await IntakeService().addConsumption(
                                    uid: uid,
                                    foodId: f["name"],
                                    foodName: f["name"],
                                    calories: f["grams"] / 100 * f["cal_per_100g"],
                                  );
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Đã lưu vào nhật ký hôm nay")),
                                );
                              },
                              child: const Text("Lưu vào nhật ký hôm nay"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}

// Custom painter line scan
class _LineScanPainter extends CustomPainter {
  final double progress; // 0 -> 1
  _LineScanPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.greenAccent.withOpacity(0.6)
      ..strokeWidth = 4;

    final y = size.height * progress;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _LineScanPainter oldDelegate) => oldDelegate.progress != progress;
}
