import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';

class EditFoodPage extends StatefulWidget {
  final String foodId;
  final dynamic data;

  const EditFoodPage({super.key, required this.foodId, required this.data});

  @override
  State<EditFoodPage> createState() => _EditFoodPageState();
}

class _EditFoodPageState extends State<EditFoodPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _caloriesController;
  late TextEditingController _ingredientsController;
  late TextEditingController _instructionsController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;

  String? _selectedCategoryId;
  String? _selectedDietId;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _diets = [];

  bool _isLoading = false;
  bool _loadingUserInfo = true;
  bool hasPermission = false;

  File? _imageFile;
  File? _videoFile;
  VideoPlayerController? _videoController;

  String? currentUserEmail;
  String? currentUserRole;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.data['name']);
    _caloriesController =
        TextEditingController(text: widget.data['calories'].toString());
    _proteinController = TextEditingController(
        text: widget.data['protein']?.toString() ?? '');
    _carbsController = TextEditingController(
        text: widget.data['carbs']?.toString() ?? '');
    _fatController = TextEditingController(
        text: widget.data['fat']?.toString() ?? '');
    _ingredientsController =
        TextEditingController(text: widget.data['ingredients']);
    _instructionsController =
        TextEditingController(text: widget.data['instructions']);

    _selectedCategoryId = widget.data['categoryId'];
    _selectedDietId = widget.data['dietId'];

    _loadUserInfo();
    _loadCategories();
  }

  Future<void> _loadUserInfo() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
  if (!userDoc.exists) return;

  final role = (userDoc['role'] ?? '').toString().toLowerCase();
  final createdBy = (widget.data['authorId'] ?? '').toString();

  debugPrint('🔍 Current user: ${user.uid}, Role: $role, CreatedBy: $createdBy');

  if (createdBy == user.uid) {
    setState(() => hasPermission = true);
  }

  setState(() {
    currentUserEmail = user.email;
    currentUserRole = role;
    _loadingUserInfo = false;
  });
}


  Future<void> _loadCategories() async {
    final snapshot = await FirebaseFirestore.instance.collection('categories').get();
    final all = snapshot.docs.map((doc) => {
          'id': doc.id,
          'name': doc['name'],
          'type': doc['type'], // theo_loai_mon_an / theo_che_do_an
        }).toList();

    setState(() {
      _categories = all.where((c) => c['type'] == 'theo_loai_mon_an').toList();
      _diets = all.where((c) => c['type'] == 'theo_che_do_an').toList();
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<void> _pickVideo() async {
    final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);
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
      final ref = FirebaseStorage.instance
          .ref()
          .child('foods/$folder/${DateTime.now().millisecondsSinceEpoch}');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi upload: $e')));
      return null;
    }
  }

  Future<void> _updateFood() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedCategoryId == null || _selectedDietId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn đủ danh mục và chế độ ăn')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imageUrl = widget.data['image_url'] ?? '';
      String videoUrl = widget.data['video_url'] ?? '';

      if (_imageFile != null) {
        final uploaded = await _uploadFile(_imageFile!, 'images');
        if (uploaded != null) imageUrl = uploaded;
      }

      if (_videoFile != null) {
        final uploaded = await _uploadFile(_videoFile!, 'videos');
        if (uploaded != null) videoUrl = uploaded;
      }

      final category = _categories.firstWhere((e) => e['id'] == _selectedCategoryId);
      final diet = _diets.firstWhere((e) => e['id'] == _selectedDietId);

      await FirebaseFirestore.instance
    .collection('foods')
    .doc(widget.foodId)
    .update({
      'name': _nameController.text.trim(),
      'calories': int.tryParse(_caloriesController.text.trim()) ?? 0,
      'protein': double.tryParse(_proteinController.text.trim()) ?? 0,
      'carbs': double.tryParse(_carbsController.text.trim()) ?? 0,
      'fat': double.tryParse(_fatController.text.trim()) ?? 0,
      'ingredients': _ingredientsController.text.trim(),
      'instructions': _instructionsController.text.trim(),
      'categoryId': category['id'],
      'categoryName': category['name'],
      'dietId': diet['id'],
      'dietName': diet['name'],
      'image_url': imageUrl,
      'video_url': videoUrl,
      'updated_at': FieldValue.serverTimestamp(),
    });


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Cập nhật thành công!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi cập nhật: $e')),
      );
    }

    setState(() => _isLoading = false);
  }

  @override
Widget build(BuildContext context) {
  if (_loadingUserInfo) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sửa món ăn')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  if (!hasPermission) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sửa món ăn')),
      body: const Center(
        child: Text(
          'Bạn không có quyền chỉnh sửa món ăn này',
          style: TextStyle(fontSize: 18, color: Colors.red),
        ),
      ),
    );
  }


  return Scaffold(
    appBar: AppBar(title: const Text('Sửa món ăn')),
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
              decoration: const InputDecoration(labelText: 'Lượng calo (kcal)'),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _proteinController,
              decoration: const InputDecoration(labelText: 'Protein (g)'),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _carbsController,
              decoration: const InputDecoration(labelText: 'Carbs (g)'),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _fatController,
              decoration: const InputDecoration(labelText: 'Fat (g)'),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedCategoryId,
              decoration: const InputDecoration(labelText: 'Danh mục món ăn'),
              items: _categories
                  .map((cat) => DropdownMenuItem<String>(
                        value: cat['id'],
                        child: Text(cat['name']),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategoryId = val),
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedDietId,
              decoration: const InputDecoration(labelText: 'Chế độ ăn'),
              items: _diets
                  .map((diet) => DropdownMenuItem<String>(
                        value: diet['id'],
                        child: Text(diet['name']),
                      ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedDietId = val),
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
              decoration: const InputDecoration(labelText: 'Các bước thực hiện'),
              maxLines: 5,
              validator: (v) => v!.isEmpty ? 'Không được bỏ trống' : null,
            ),
            const SizedBox(height: 16),

            if (_imageFile != null)
              Image.file(_imageFile!, height: 200, fit: BoxFit.cover)
            else if (widget.data['image_url'] != null &&
                widget.data['image_url'].isNotEmpty)
              Image.network(widget.data['image_url'],
                  height: 200, fit: BoxFit.cover),

            const SizedBox(height: 8),

            if (_videoFile != null &&
                _videoController != null &&
                _videoController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              )
            else if (widget.data['video_url'] != null &&
                widget.data['video_url'].isNotEmpty)
              const Text('🎬 Video hiện tại có sẵn'),

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
              onPressed: _isLoading ? null : _updateFood,
              icon: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: const Text('Cập nhật món ăn'),
            ),
          ],
        ),
      ),
    ),
  );
}
}