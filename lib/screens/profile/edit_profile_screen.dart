import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/profile_service.dart';
import '../../services/calorie_service.dart';

class EditProfileScreen extends StatefulWidget {
  final String userId;
  const EditProfileScreen({super.key, required this.userId});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _svc = ProfileService();

  final _nameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();

  // THÊM: các field thông tin cơ thể
  final _ageCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _targetWeightCtrl = TextEditingController();

  bool _initializedFromFirestore = false;
  bool _busy = false;

  String _gender = 'Nữ';
  String? _goal;
  String? _dietType;

  double _activityFactor = 1.375;
  final List<String> _goals = const [
    'Giảm cân',
    'Giảm mỡ',
    'Giữ dáng',
    'Tăng cân',
    'Tăng cơ',
    'Tăng sức bền',
    'Tăng sức mạnh',
    'Cải thiện sức khỏe',
    'Giảm mỡ bụng',
  ];

  List<String> _dietTypes = [];
  bool _loadingDiets = true;

  @override
  void initState() {
    super.initState();
    _loadDietTypes();
  }

  Future<void> _loadDietTypes() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('categories')
          .where('type', isEqualTo: 'theo_che_do_an')
          .get();

      setState(() {
        _dietTypes = snap.docs
            .map((d) => (d.data()['name'] as String?)?.trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList()
          ..sort();
        _loadingDiets = false;
      });
    } catch (e) {
      debugPrint('Lỗi load chế độ ăn: $e');
      if (!mounted) return;
      setState(() {
        _dietTypes = [];
        _loadingDiets = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _targetWeightCtrl.dispose();
    super.dispose();
  }

  // ====== HÀM PARSE SỐ DÙNG CHUNG ======
  double? _parseDouble(String text) {
    final raw = text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return null;
    return double.tryParse(raw);
  }

  // ================= HELPERS =================
  /// Trả về ImageProvider thích hợp từ một URL/đường dẫn (http(s) hoặc file:// hoặc path)
  ImageProvider<Object>? imageProviderFromUrl(String? url) {
    if (url == null) return null;
    final s = url.trim();
    if (s.isEmpty) return null;
    try {
      final uri = Uri.parse(s);
      if (uri.scheme == 'http' || uri.scheme == 'https') {
        return NetworkImage(s);
      } else if (uri.scheme == 'file') {
        final path = uri.toFilePath();
        return FileImage(File(path));
      } else if (!uri.hasScheme) {
        // có thể là một đường dẫn file ("/storage/..." hoặc "C:\\...") -> thử FileImage
        if (s.startsWith('/') || s.startsWith(r'\\') || s.contains(':\\')) {
          return FileImage(File(s));
        }
      }
    } catch (_) {
      // fallback
      if (s.startsWith('http')) return NetworkImage(s);
      if (s.startsWith('/')) return FileImage(File(s));
    }
    return null;
  }

  /// Snap một giá trị activity factor về gần nhất trong danh sách option để tránh lỗi Dropdown
  double snapToActivityOption(double raw) {
    const allowed = [1.2, 1.375, 1.55, 1.725, 1.9];
    double best = allowed.first;
    double bestDiff = (raw - best).abs();
    for (final v in allowed) {
      final d = (raw - v).abs();
      if (d < bestDiff) {
        best = v;
        bestDiff = d;
      }
    }
    return best;
  }

  Future<void> _pickAndUploadAvatar() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid != widget.userId) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _busy = true);
    try {
      await _svc.uploadAvatar(user: me, image: File(picked.path));
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã cập nhật ảnh đại diện')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || me.uid != widget.userId) return;

    setState(() => _busy = true);
    try {
      // 1) Cập nhật tên + bio
      await _svc.updateProfile(
        user: me,
        displayName: _nameCtrl.text.trim(),
        bio: _bioCtrl.text.trim(),
      );

      // 2) Parse số (dùng hàm _parseDouble ở trên)
      final int? age = int.tryParse(_ageCtrl.text.trim());
      final double? weight = _parseDouble(_weightCtrl.text);
      final double? height = _parseDouble(_heightCtrl.text);
      final double? targetWeight = _parseDouble(_targetWeightCtrl.text);

      debugPrint('>>> SAVE PROFILE');
      debugPrint('   age=$age, weight=$weight, height=$height, targetWeight=$targetWeight');
      debugPrint('   goal=$_goal, gender=$_gender, dietType=$_dietType');

      double? bmi;
      if (weight != null && height != null && weight > 0 && height > 0) {
        final h = height / 100;
        bmi = double.parse((weight / (h * h)).toStringAsFixed(1));
      }

      // ===== TÍNH LẠI BMR / TDEE / CALO =====
      double? bmr;
      double? tdee;
      int? dailyGoal;
      int? proteinGr, carbsGr, fatGr;

      if (weight != null && height != null && age != null && age > 0) {
        final bool isMale = _gender == 'Nam';

        double rawBmr;
        if (isMale) {
          rawBmr = 10 * weight + 6.25 * height - 5 * age + 5;
        } else {
          rawBmr = 10 * weight + 6.25 * height - 5 * age - 161;
        }

        double rawTdee = rawBmr * _activityFactor;
        double goalCalories = rawTdee;

        const loseGoals = [
          'Giảm cân',
          'Giảm mỡ',
          'Giảm mỡ bụng',
        ];
        const gainGoals = [
          'Tăng cân',
          'Tăng cơ',
          'Tăng sức bền',
          'Tăng sức mạnh',
        ];

        double delta = 0;

        // Điều chỉnh theo targetWeight
        if (targetWeight != null) {
          final diff = targetWeight - weight; // âm: giảm, dương: tăng

          if (diff < 0) {
            final absDiff = diff.abs();
            if (absDiff > 15) {
              delta = -700;
            } else if (absDiff >= 5) {
              delta = -500;
            } else {
              delta = -300;
            }
          } else if (diff > 0) {
            if (diff > 10) {
              delta = 700;
            } else if (diff >= 4) {
              delta = 500;
            } else {
              delta = 300;
            }
          }
        }

        // Ưu tiên mục tiêu nếu có chọn
        if (_goal != null && loseGoals.contains(_goal)) {
          if (delta >= 0) delta = -500;
        } else if (_goal != null && gainGoals.contains(_goal)) {
          if (delta <= 0) delta = 500;
        }

        goalCalories = rawTdee + delta;

        bmr = rawBmr;
        tdee = rawTdee;
        dailyGoal = goalCalories.clamp(800, 6000).round();

        debugPrint('   BMR=$bmr, TDEE=$tdee, dailyGoal=$dailyGoal, delta=$delta');

        // macros
        proteinGr = ((dailyGoal * 0.25) / 4).round();
        fatGr = ((dailyGoal * 0.30) / 9).round();
        carbsGr = ((dailyGoal * 0.45) / 4).round();

        debugPrint('Protein=$proteinGr g, Fat=$fatGr g, Carbs=$carbsGr g');
      }

      // 3) Dữ liệu update lên Firestore
      final updateData = <String, dynamic>{
        'gender': _gender,
        'age': age,
        'weight': weight,
        'height': height,
        'targetWeight': targetWeight,
        'goal': _goal,
        'dietType': _dietType,
        'bmi': bmi,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // nếu đã tính calo thì lưu cả calorieGoal map + duplicate fields (Home đang đọc calorieGoal)
      if (bmr != null && tdee != null && dailyGoal != null) {
        final calorieGoalMap = <String, dynamic>{
          'bmr': bmr.round(),
          'tdee': tdee.round(),
          'dailyGoal': dailyGoal,
          'protein': proteinGr,
          'carbs': carbsGr,
          'fat': fatGr,
        };
        updateData['calorieGoal'] = calorieGoalMap;

        // duplicate để dễ đọc các màn cũ
        updateData['bmr'] = calorieGoalMap['bmr'];
        updateData['tdee'] = calorieGoalMap['tdee'];
        updateData['dailyGoal'] = calorieGoalMap['dailyGoal'];
        updateData['protein'] = calorieGoalMap['protein'];
        updateData['carbs'] = calorieGoalMap['carbs'];
        updateData['fat'] = calorieGoalMap['fat'];
      }

      debugPrint('   updateData=$updateData');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(me.uid)
          .set(updateData, SetOptions(merge: true));

      // 4) Lưu mục tiêu calo (service) — vẫn giữ nếu bạn cần logic thêm ở service
      if (bmr != null && tdee != null && dailyGoal != null) {
        await CalorieService.instance.saveDailyGoal(
          bmr: bmr.round(),
          tdee: tdee.round(),
          dailyGoal: dailyGoal,
          protein: proteinGr,
          carbs: carbsGr,
          fat: fatGr,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã lưu hồ sơ')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      debugPrint('>>> ERROR SAVE PROFILE: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;
    final isMe = me?.uid == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa hồ sơ'),
        actions: [
          IconButton(
            tooltip: 'Lưu',
            icon: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            onPressed: _busy || !isMe ? null : _save,
          ),
        ],
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: _svc.userStream(widget.userId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? {};
          final photoURL = (data['photoURL'] ?? '') as String;
          final displayName = (data['displayName'] ?? '') as String;
          final bio = (data['bio'] ?? '') as String;

          // THÊM: lấy các field mới từ Firestore
          final gender = (data['gender'] ?? _gender) as String;
          final int? age = (data['age'] as num?)?.toInt();
          final double? weight = (data['weight'] as num?)?.toDouble();
          final double? height = (data['height'] as num?)?.toDouble();
          final double? targetWeight =
              (data['targetWeight'] as num?)?.toDouble();
          final String? goal = data['goal'] as String?;
          final String? dietType = data['dietType'] as String?;

          // Nếu đã từng tính calo rồi thì suy ra activityFactor từ bmr & tdee
          final Map<String, dynamic>? calorieGoalData =
              data['calorieGoal'] as Map<String, dynamic>?;

          if (calorieGoalData != null) {
            final num? bmrVal = calorieGoalData['bmr'] as num?;
            final num? tdeeVal = calorieGoalData['tdee'] as num?;
            if (bmrVal != null && bmrVal > 0 && tdeeVal != null && tdeeVal > 0) {
              final factor = tdeeVal / bmrVal;
              if (factor > 0 && factor < 3) {
                // snap về option hợp lệ tránh lỗi Dropdown
                _activityFactor = snapToActivityOption(factor.toDouble());
              }
            }
          }

          // SAU KHI LẤY data / gender / age / weight / height / targetWeight / goal / dietType xong:

          if (!_initializedFromFirestore) {
            _initializedFromFirestore = true;

            _nameCtrl.text = displayName;
            _bioCtrl.text = bio;

            _ageCtrl.text = age?.toString() ?? '';
            _weightCtrl.text = weight?.toString() ?? '';
            _heightCtrl.text = height?.toString() ?? '';
            _targetWeightCtrl.text = targetWeight?.toString() ?? '';

            _gender = gender;
            _goal = goal;
            _dietType = dietType;
          }

          final avatarImage = imageProviderFromUrl(photoURL);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // AVATAR
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? const Icon(Icons.person, size: 48)
                            : null,
                      ),
                      if (isMe)
                        IconButton.filled(
                          onPressed: _busy ? null : _pickAndUploadAvatar,
                          icon: const Icon(Icons.camera_alt, size: 18),
                          tooltip: 'Đổi ảnh đại diện',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // TÊN + BIO
                TextField(
                  controller: _nameCtrl,
                  enabled: isMe && !_busy,
                  decoration: const InputDecoration(
                    labelText: 'Tên hiển thị',
                    hintText: 'Nhập tên hiển thị',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bioCtrl,
                  enabled: isMe && !_busy,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Giới thiệu',
                    hintText: 'Mô tả ngắn về bạn...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 24),

                const Text(
                  'Thông tin cơ thể',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),

                // GIỚI TÍNH + TUỔI
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Giới tính'),
                          const SizedBox(height: 6),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _gender,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Nữ',
                                    child: Text('Nữ'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Nam',
                                    child: Text('Nam'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Khác',
                                    child: Text('Khác / Không tiết lộ'),
                                  ),
                                ],
                                onChanged: !_busy && isMe
                                    ? (val) {
                                        if (val != null) {
                                          setState(() => _gender = val);
                                        }
                                      }
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _ageCtrl,
                        enabled: isMe && !_busy,
                        keyboardType:
                            const TextInputType.numberWithOptions(),
                        decoration: const InputDecoration(
                          labelText: 'Tuổi',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // CÂN NẶNG + CHIỀU CAO
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _weightCtrl,
                        enabled: isMe && !_busy,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cân nặng (kg)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _heightCtrl,
                        enabled: isMe && !_busy,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Chiều cao (cm)',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // CÂN NẶNG MỤC TIÊU
                TextField(
                  controller: _targetWeightCtrl,
                  enabled: isMe && !_busy,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Cân nặng mục tiêu (kg, có thể để trống)',
                  ),
                ),

                const SizedBox(height: 24),
                // MỨC ĐỘ VẬN ĐỘNG
                const SizedBox(height: 12),
                Text('Mức độ vận động', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<double>(
                      isExpanded: true,
                      value: _activityFactor,
                      items: const [
                        DropdownMenuItem(value: 1.2, child: Text('Ít vận động')),
                        DropdownMenuItem(value: 1.375, child: Text('Hoạt động nhẹ')),
                        DropdownMenuItem(value: 1.55, child: Text('Vừa phải')),
                        DropdownMenuItem(value: 1.725, child: Text('Năng động')),
                        DropdownMenuItem(value: 1.9, child: Text('Rất năng động')),
                      ],
                      onChanged: !_busy && isMe ? (val) {
                        if (val != null) setState(() => _activityFactor = val);
                      } : null,
                    ),
                  ),
                ),

                const Text(
                  'Mục tiêu của bạn',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _goals.map((g) {
                    final selected = _goal == g;
                    return ChoiceChip(
                      label: Text(g),
                      selected: selected,
                      onSelected: !_busy && isMe
                          ? (_) {
                              setState(() {
                                _goal = g;
                              });
                            }
                          : null,
                      selectedColor: Colors.green,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.black87,
                      ),
                      backgroundColor: Colors.white,
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),
                const Text(
                  'Chế độ ăn',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),

                if (_loadingDiets)
                  const Center(child: CircularProgressIndicator())
                else if (_dietTypes.isEmpty)
                  const Text(
                    'Chưa có danh mục chế độ ăn.\nHãy thêm trong trang Quản lý danh mục.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _dietTypes.map((d) {
                      final selected = _dietType == d;
                      return ChoiceChip(
                        label: Text(d),
                        selected: selected,
                        onSelected: !_busy && isMe
                            ? (_) {
                                setState(() {
                                  _dietType = d;
                                });
                              }
                            : null,
                        selectedColor: Colors.green,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.black87,
                        ),
                        backgroundColor: Colors.white,
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
    );
  }
}
