import 'dart:io';
import 'package:flutter/material.dart';
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

class _CalorieScanScreenState extends State<CalorieScanScreen> {
  final picker = ImagePicker();
  final vision = GoogleVisionService();
  File? _image;

  List<Map<String, dynamic>> detectedFoods = [];
  bool scanning = false;

  Future pickImage(ImageSource src) async {
    final file = await picker.pickImage(source: src);
    if (file != null) {
      setState(() => _image = File(file.path));
    }
  }

  Future analyzeMeal() async {
    if (_image == null) return;

    setState(() {
      scanning = true;
      detectedFoods.clear();
    });

    final labels = await vision.detectLabels(_image!);

    /// GHÉP AI → DATABASE 200 MÓN
    for (var label in labels) {
      final l = label.toLowerCase();

      for (var food in foodDB) {
        if (l.contains(food["keyword"])) {
          detectedFoods.add({
            "name": food["name"],
            "grams": 100,
            "cal_per_100g": food["cal"],
          });
        }
      }
    }

    setState(() => scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    double totalCal = 0;
    for (var f in detectedFoods) {
      totalCal += f["grams"] / 100 * f["cal_per_100g"];
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Quét calo bữa ăn")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 250,
              color: Colors.grey.shade200,
              child: _image == null
                  ? const Icon(Icons.image, size: 100)
                  : Image.file(_image!, fit: BoxFit.cover),
            ),

            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Chụp hình"),
                ),
                ElevatedButton.icon(
                  onPressed: () => pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo),
                  label: const Text("Thư viện"),
                ),
              ],
            ),

            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: scanning ? null : analyzeMeal,
              child: scanning
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("🔍 Phân tích bữa ăn"),
            ),

            const SizedBox(height: 20),

            if (detectedFoods.isNotEmpty) ...[
              const Text("Thành phần bữa ăn", style: TextStyle(fontSize: 18)),

              const SizedBox(height: 10),

              Column(
                children: detectedFoods.map((food) {
                  return Card(
                    child: ListTile(
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
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              Text(
                "Tổng: ${totalCal.round()} kcal",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 20),

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
          ],
        ),
      ),
    );
  }
}
