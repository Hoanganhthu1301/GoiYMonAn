import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:doan/services/ingredient_keyword_service.dart';
import 'package:doan/services/keyword_generator_service.dart';

class AddFoodPage extends StatefulWidget {
  const AddFoodPage({super.key});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _instructionsController = TextEditingController();

  String? _selectedCategoryId; // loại hình món ăn
  String? _selectedDietId; // chế độ ăn

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _diets = [];

  bool _isLoading = false;
  File? _imageFile;
  File? _videoFile;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('categories')
        .get();

    // Tách danh mục ra 2 nhóm
    final all = snapshot.docs
        .map(
          (doc) => {
            'id': doc.id,
            'name': doc['name'],
            'type': doc['type'], // "loai_hinh" hoặc "che_do_an"
          },
        )
        .toList();

    setState(() {
      _categories = all.where((c) => c['type'] == 'theo_loai_mon_an').toList();
      _diets = all.where((c) => c['type'] == 'theo_che_do_an').toList();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _ingredientsController.dispose();
    _instructionsController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<void> _pickVideo() async {
    final pickedFile = await ImagePicker().pickVideo(
      source: ImageSource.gallery,
    );
    if (pickedFile != null) {
      setState(() => _videoFile = File(pickedFile.path));
      _videoController?.dispose();
      _videoController = VideoPlayerController.file(_videoFile!)
        ..initialize().then((_) {
          setState(() {});
          _videoController!.play();
        });
    }
  }

  Future<String?> _uploadFile(File file, String folder) async {
    try {
      final ref = FirebaseStorage.instance.ref().child(
        'foods/$folder/${DateTime.now().millisecondsSinceEpoch}',
      );
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi upload: $e')));
      return null;
    }
  }

  Future<void> _saveFood() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategoryId == null || _selectedDietId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn đầy đủ danh mục và chế độ ăn'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;

    // UPLOAD ẢNH & VIDEO
    String? imageUrl;
    String? videoUrl;

    if (_imageFile != null) imageUrl = await _uploadFile(_imageFile!, 'images');
    if (_videoFile != null) videoUrl = await _uploadFile(_videoFile!, 'videos');

    // Lấy category & diet info
    final category = _categories.firstWhere(
      (e) => e['id'] == _selectedCategoryId,
    );
    final diet = _diets.firstWhere((e) => e['id'] == _selectedDietId);

    // ===============================
    // ⭐ TỰ ĐỘNG SINH KEYWORDS ⭐
    // ===============================

    final ingredientService = IngredientKeywordService();
    final visionService = KeywordGeneratorService();

    // Keywords từ nguyên liệu người nhập
    final ingredientKeywords = await ingredientService.generateKeywords(
      _ingredientsController.text.trim(),
    );

    // Keywords từ ảnh Vision API
    List<String> imageKeywords = [];
    if (_imageFile != null) {
      imageKeywords = await visionService.generateKeywords(_imageFile!);
    }

    // Gộp 2 nguồn keywords
    final keywords = {...ingredientKeywords, ...imageKeywords}.toList();

    // ===============================

    await FirebaseFirestore.instance.collection('foods').add({
      'name': _nameController.text.trim(),
      'calories': int.tryParse(_caloriesController.text.trim()) ?? 0,
      'ingredients': _ingredientsController.text.trim(),
      'instructions': _instructionsController.text.trim(),
      'categoryId': category['id'],
      'categoryName': category['name'],
      'dietId': diet['id'],
      'dietName': diet['name'],
      'image_url': imageUrl ?? '',
      'video_url': videoUrl ?? '',
      'keywords': keywords, // ⭐ LƯU KEYWORDS VÀO FIRESTORE ⭐
      'authorId': user?.uid,
      'authorEmail': user?.email ?? 'Ẩn danh',
      'created_at': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Thêm món ăn thành công!')));
      Navigator.pop(context);
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm món ăn mới')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Tên món ăn'),
                validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _caloriesController,
                decoration: const InputDecoration(
                  labelText: 'Lượng calo (kcal)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedCategoryId,
                decoration: const InputDecoration(labelText: 'Danh mục món ăn'),
                items: _categories
                    .map(
                      (cat) => DropdownMenuItem<String>(
                        value: cat['id'],
                        child: Text(cat['name']),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedCategoryId = val),
                validator: (v) => v == null ? 'Chọn danh mục món ăn' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedDietId,
                decoration: const InputDecoration(labelText: 'Chế độ ăn'),
                items: _diets
                    .map(
                      (diet) => DropdownMenuItem<String>(
                        value: diet['id'],
                        child: Text(diet['name']),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedDietId = val),
                validator: (v) => v == null ? 'Chọn chế độ ăn' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _ingredientsController,
                decoration: const InputDecoration(labelText: 'Nguyên liệu'),
                maxLines: 3,
                validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Các bước thực hiện',
                ),
                maxLines: 5,
                validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
              ),
              const SizedBox(height: 16),

              if (_imageFile != null)
                Image.file(_imageFile!, height: 200, fit: BoxFit.cover),
              const SizedBox(height: 8),

              if (_videoFile != null &&
                  _videoController != null &&
                  _videoController!.value.isInitialized)
                AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio,
                  child: VideoPlayer(_videoController!),
                ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Chọn ảnh'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.videocam),
                      label: const Text('Chọn video'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: _isLoading ? null : _saveFood,
                icon: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: const Text('Lưu món ăn'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
