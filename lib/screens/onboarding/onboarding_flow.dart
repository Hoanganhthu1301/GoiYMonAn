// lib/screens/onboarding/onboarding_flow.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/calorie_service.dart';
import '../home/home_screen.dart';
import '../dashboard_screen.dart'; // <-- thêm import Dashboard

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Chào mừng đến với CaloFit',
      subtitle:
          'Ứng dụng tính calo & gợi ý món ăn giúp bạn ăn ngon mà vẫn giữ dáng.',
      icon: Icons.restaurant,
    ),
    _OnboardingPageData(
      title: 'Theo dõi calo mỗi ngày',
      subtitle: 'Ghi lại món ăn, xem tổng calo đã ăn và lượng calo còn lại.',
      icon: Icons.local_fire_department,
    ),
    _OnboardingPageData(
      title: 'Gợi ý thực đơn phù hợp',
      subtitle:
          'Nhận gợi ý món ăn theo mục tiêu và chế độ ăn mà bạn lựa chọn.',
      icon: Icons.menu_book,
    ),
  ];

  void _goNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const PreferenceSelectionScreen(),
        ),
      );
    }
  }

  void _skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const PreferenceSelectionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorPrimary = Theme.of(context).colorScheme.primary;
    final darkText =
        Theme.of(context).textTheme.titleMedium?.color ?? Colors.black87;
    final subText =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black54;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _skip,
                child: Text('Bỏ qua', style: TextStyle(color: subText)),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(page.icon, size: 90, color: colorPrimary),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(color: darkText),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: subText, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DotsIndicator(length: _pages.length, currentIndex: _currentPage),
                  ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorPrimary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: Text(_currentPage == _pages.length - 1 ? 'Bắt đầu' : 'Tiếp tục'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String subtitle;
  final IconData icon;

  const _OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _DotsIndicator extends StatelessWidget {
  final int length;
  final int currentIndex;

  const _DotsIndicator({super.key, required this.length, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: List.generate(length, (index) {
        final bool isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: isActive ? 20 : 8,
          decoration: BoxDecoration(
            color: isActive ? primary : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(12),
          ),
        );
      }),
    );
  }
}

/// PREFERENCE SELECTION (goal + diet)
class PreferenceSelectionScreen extends StatefulWidget {
  const PreferenceSelectionScreen({super.key});

  @override
  State<PreferenceSelectionScreen> createState() => _PreferenceSelectionScreenState();
}

class _PreferenceSelectionScreenState extends State<PreferenceSelectionScreen> {
  String? _selectedGoal;
  String? _selectedDiet;

  final List<String> goals = [
    'Giảm cân',
    'Giảm mỡ',
    'Giữ cân',
    'Tăng cân',
    'Tăng cơ',
    'Giữ dáng',
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
    _loadDietTypesFromFirestore();
  }

  Future<void> _loadDietTypesFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('categories')
          .where('type', isEqualTo: 'theo_che_do_an')
          .get();
      final list = snap.docs
          .map((d) => (d.data()['name'] as String?)?.trim() ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      setState(() {
        _dietTypes = list;
        _loadingDiets = false;
      });
    } catch (e) {
      debugPrint('Lỗi load chế độ ăn: $e');
      setState(() {
        _dietTypes = [];
        _loadingDiets = false;
      });
    }
  }

  void _goNext() {
    // LƯU tạm goal + diet vào users doc trước khi vào ProfileSetup để Home/other screens có thể đọc ngay
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final Map<String, dynamic> partial = {};
      if (_selectedGoal != null) {
        partial['goal'] = _selectedGoal;
      }
      if (_selectedDiet != null) {
        partial['dietType'] = _selectedDiet;
      }
      if (partial.isNotEmpty) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).set(partial, SetOptions(merge: true));
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileSetupScreen(
          initialGoal: _selectedGoal,
          initialDietType: _selectedDiet,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorPrimary = Theme.of(context).colorScheme.primary;
    final canContinue = _selectedGoal != null && _selectedDiet != null;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        title: const Text('Chọn mục tiêu & chế độ ăn'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Preference Selection / Interest Picker',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              const Text('Mục tiêu của bạn là gì?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: goals.map((goal) {
                  final bool selected = _selectedGoal == goal;
                  return ChoiceChip(
                    label: Text(goal),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedGoal = goal),
                    selectedColor: colorPrimary,
                    labelStyle: TextStyle(
                      color: selected ? Theme.of(context).colorScheme.onPrimary : null,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text('Bạn muốn theo chế độ ăn nào?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_loadingDiets)
                const Padding(padding: EdgeInsets.all(8.0), child: Center(child: CircularProgressIndicator()))
              else if (_dietTypes.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Text('Chưa có danh mục chế độ ăn.\nHãy thêm trong trang Quản lý danh mục.'),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _dietTypes.map((diet) {
                    final bool selected = _selectedDiet == diet;
                    return ChoiceChip(
                      label: Text(diet),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedDiet = diet),
                      selectedColor: colorPrimary,
                      labelStyle: TextStyle(
                        color: selected ? Theme.of(context).colorScheme.onPrimary : null,
                      ),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    );
                  }).toList(),
                ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canContinue ? _goNext : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Tiếp tục', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// PROFILE SETUP (no goal editing here — goal/diet come from previous screen)
class ProfileSetupScreen extends StatefulWidget {
  final String? initialGoal;
  final String? initialDietType;

  const ProfileSetupScreen({super.key, this.initialGoal, this.initialDietType});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _heightController = TextEditingController(); // ensure consistent name
  final TextEditingController _targetWeightController = TextEditingController();

  String _gender = 'Nữ';
  double? _bmi;
  String _bmiStatus = '';
  String _bmiAdvice = '';

  double _activityFactor = 1.2;
  // internal calorieMode (kept mutable if you later want to allow editing)
  String _calorieMode = 'maintain';

  int? _bmr;
  int? _tdee;
  int? _dailyGoal;

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _targetWeightController.dispose();
    super.dispose();
  }

// Thay thế toàn bộ hàm _recalculateBmi() bằng đoạn này
void _recalculateBmi() {
  final weight = double.tryParse(_weightController.text.trim());
  final heightCm = double.tryParse(_heightController.text.trim());
  final targetWeight = double.tryParse(_targetWeightController.text.trim());

  if (weight == null || heightCm == null || weight <= 0 || heightCm <= 0) {
    setState(() {
      _bmi = null;
      _bmiStatus = '';
      _bmiAdvice = '';
    });
    return;
  }

  final h = heightCm / 100;
  final bmi = weight / (h * h);

  String status;
  if (bmi < 18.5) {
    status = 'Thiếu cân';
  } else if (bmi < 23) {
    status = 'Bình thường';
  } else if (bmi < 27.5) {
    status = 'Thừa cân';
  } else {
    status = 'Béo phì';
  }

  final goal = widget.initialGoal;
  String advice;

  // thêm kiểm tra mẫu mục tiêu + targetWeight để đưa cảnh báo rõ ràng hơn
  double? percChange;
  if (targetWeight != null && weight > 0) {
    percChange = ((weight - targetWeight) / weight) * 100; // phần trăm giảm (dương nếu giảm)
  }

  // Trường hợp nghiêm trọng: thiếu cân nhưng chọn giảm cân -> cảnh báo mạnh
  if (status == 'Thiếu cân' && (goal == 'Giảm cân' || goal == 'Giảm mỡ')) {
    advice = 'CẢNH BÁO: BMI của bạn đang dưới chuẩn. Việc chọn mục tiêu "Giảm cân" có thể gây hại — hãy cân nhắc "Giữ cân" hoặc "Tăng cân", hoặc hỏi ý kiến chuyên gia y tế.';
  }
  // Nếu BMI bình thường nhưng chọn giảm — khuyên nhẹ nhàng
  else if (status == 'Bình thường' && (goal == 'Giảm cân' || goal == 'Giảm mỡ')) {
    // nếu targetWeight quá thấp -> tăng độ cảnh báo
    if (percChange != null && percChange > 10) {
      advice = 'Bạn đang ở mức BMI bình thường nhưng mục tiêu giảm → MỨC GIẢM ${percChange.toStringAsFixed(0)}% so với cân hiện tại. Hãy đặt mục tiêu nhẹ nhàng (≤10%) hoặc tham khảo chuyên gia.';
    } else {
      advice = 'BMI của bạn ở mức bình thường. Nếu vẫn muốn giảm cân, hãy đặt mục tiêu nhẹ nhàng và giảm từ từ để an toàn.';
    }
  }
  // Nếu thừa cân/béo phì nhưng mục tiêu tăng hoặc giữ -> nhắc xem lại
  else if ((status == 'Thừa cân' || status == 'Béo phì') && (goal == 'Giữ cân' || goal == 'Tăng cân')) {
    advice = 'Lưu ý: BMI hiện tại cho thấy bạn đang thừa cân. Nếu bạn chọn "Giữ cân" hoặc "Tăng cân", hãy đảm bảo bạn hiểu lý do và theo dõi sức khỏe kỹ lưỡng.';
  }
  // Mặc định: đưa lời khuyên theo status
  else {
    if (status == 'Bình thường') {
      advice = 'BMI của bạn ở mức bình thường. Giữ thói quen ăn uống và vận động hợp lý.';
    } else if (status == 'Thiếu cân') {
      advice = 'Bạn đang thiếu cân. Nên tập trung ăn đủ dinh dưỡng và cân nhắc mục tiêu tăng/giữ cân.';
    } else {
      advice = 'BMI cao hơn mức bình thường. Nên cân nhắc giảm cân an toàn kết hợp chế độ ăn và vận động.';
    }
  }

  setState(() {
    _bmi = double.parse(bmi.toStringAsFixed(1));
    _bmiStatus = status;
    _bmiAdvice = advice;
  });
}

// Thay thế toàn bộ hàm _finish() bằng đoạn này
Future<void> _finish() async {
  if (!_formKey.currentState!.validate()) return;

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn chưa đăng nhập.')));
      return;
    }
    final uid = user.uid;

    final int? age = int.tryParse(_ageController.text.trim());
    final double? weight = double.tryParse(_weightController.text.trim());
    final double? height = double.tryParse(_heightController.text.trim());
    final double? targetWeight = double.tryParse(_targetWeightController.text.trim());

    // đảm bảo BMI đã được tính
    if (_bmi == null && weight != null && height != null) {
      final h = height / 100;
      final bmi = weight / (h * h);
      _bmi = double.parse(bmi.toStringAsFixed(1));
      // cập nhật status/advice ngay trước khi lưu
      _recalculateBmi();
    }

    // kiểm tra xung đột nghiêm trọng trước khi lưu:
    // - thiếu cân + mục tiêu giảm => show dialog cảnh báo (người dùng phải confirm)
    // - hoặc targetWeight khiến giảm >15% => cảnh báo confirm
    bool needConfirm = false;
    String confirmMessage = '';

    final goal = widget.initialGoal;
    if (_bmi != null) {
      if ((_bmi! < 18.5) && (goal == 'Giảm cân' || goal == 'Giảm mỡ')) {
        needConfirm = true;
        confirmMessage = 'BMI hiện tại của bạn là ${_bmi!.toStringAsFixed(1)} (Thiếu cân) nhưng bạn chọn mục tiêu giảm cân. Việc này có thể không an toàn. Bạn vẫn muốn tiếp tục lưu?';
      } else if (targetWeight != null && weight != null) {
        final perc = ((weight - targetWeight) / weight) * 100;
        if (perc > 15 && (goal == 'Giảm cân' || goal == 'Giảm mỡ')) {
          needConfirm = true;
          confirmMessage = 'Mục tiêu cân nặng bạn nhập đồng nghĩa giảm khoảng ${perc.toStringAsFixed(0)}% so với cân hiện tại — điều này là khá lớn. Bạn có chắc muốn tiếp tục?';
        }
      }
    }

    if (needConfirm) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Xác nhận mục tiêu'),
          content: Text(confirmMessage),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Tiếp tục')),
          ],
        ),
      );
      if (proceed != true) return; // hủy lưu
    }

    // giờ tính và lưu (logic tính calorieGoal giữ nguyên)
    int? bmr;
    int? tdee;
    int? dailyGoal;
    int? protein;
    int? carbs;
    int? fat;

    if (age != null && weight != null && height != null) {
      final bool isMale = _gender == 'Nam';
      double bmrDouble = isMale
          ? 10 * weight + 6.25 * height - 5 * age + 5
          : 10 * weight + 6.25 * height - 5 * age - 161;
      final tdeeDouble = bmrDouble * _activityFactor;
      double goalDouble = tdeeDouble;
      if (_calorieMode == 'lose') goalDouble = tdeeDouble - 500;
      else if (_calorieMode == 'gain') goalDouble = tdeeDouble + 500;

      bmr = bmrDouble.round();
      tdee = tdeeDouble.round();
      dailyGoal = goalDouble.round().clamp(800, 6000);

      protein = ((dailyGoal * 0.25) / 4).round();
      carbs = ((dailyGoal * 0.50) / 4).round();
      fat = ((dailyGoal * 0.25) / 9).round();

      setState(() {
        _bmr = bmr;
        _tdee = tdee;
        _dailyGoal = dailyGoal;
      });
    }

    final Map<String, dynamic> calorieGoalMap = {};
    if (bmr != null) calorieGoalMap['bmr'] = bmr;
    if (tdee != null) calorieGoalMap['tdee'] = tdee;
    if (dailyGoal != null) calorieGoalMap['dailyGoal'] = dailyGoal;
    if (protein != null) calorieGoalMap['protein'] = protein;
    if (carbs != null) calorieGoalMap['carbs'] = carbs;
    if (fat != null) calorieGoalMap['fat'] = fat;

    final Map<String, dynamic> profileData = {
      'displayName': _nameController.text.trim(),
      'gender': _gender,
      'age': age,
      'weight': weight,
      'height': height,
      'targetWeight': targetWeight,
      'bmi': _bmi,
      // lưu goal + dietType nhưng không cho sửa ở UI này
      'goal': widget.initialGoal,
      'dietType': widget.initialDietType,
      'activityFactor': _activityFactor,
      'calorieMode': _calorieMode,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (calorieGoalMap.isNotEmpty) {
      profileData['calorieGoal'] = calorieGoalMap;
      profileData['bmr'] = calorieGoalMap['bmr'];
      profileData['tdee'] = calorieGoalMap['tdee'];
      profileData['dailyGoal'] = calorieGoalMap['dailyGoal'];
      profileData['protein'] = calorieGoalMap['protein'];
      profileData['carbs'] = calorieGoalMap['carbs'];
      profileData['fat'] = calorieGoalMap['fat'];
    }

    await FirebaseFirestore.instance.collection('users').doc(uid).set(profileData, SetOptions(merge: true));

    if (_nameController.text.trim().isNotEmpty) {
      await user.updateDisplayName(_nameController.text.trim());
      await user.reload();
    }

    if (bmr != null && tdee != null && dailyGoal != null) {
      try {
        await CalorieService.instance.saveDailyGoal(
          bmr: bmr,
          tdee: tdee,
          dailyGoal: dailyGoal,
          protein: protein,
          carbs: carbs,
          fat: fat,
        );
      } catch (_) {}
    }

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const DashboardScreen()), (route) => false);
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi lưu hồ sơ: $e')));
  }
}

  @override
  Widget build(BuildContext context) {
    final goal = widget.initialGoal ?? 'Chưa chọn';
    final diet = widget.initialDietType ?? 'Chưa chọn';
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: const Text('Thiết lập hồ sơ'), centerTitle: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Profile Setup', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            // Hiển thị mục tiêu + chế độ ăn (read-only)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Icon(Icons.flag, color: primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Mục tiêu: $goal\nChế độ ăn: $diet', style: Theme.of(context).textTheme.bodyMedium)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(children: [
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Giới tính', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            value: _gender,
                            items: const [
                              DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                              DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                              DropdownMenuItem(value: 'Khác', child: Text('Khác / Không tiết lộ')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _gender = val);
                            },
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: const TextInputType.numberWithOptions(),
                      decoration: const InputDecoration(labelText: 'Tuổi'),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Nhập tuổi';
                        final num? value = num.tryParse(val);
                        if (value == null || value <= 0 || value > 120) return 'Tuổi không hợp lệ';
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _recalculateBmi(),
                      decoration: const InputDecoration(labelText: 'Cân nặng (kg)'),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Nhập cân nặng';
                        final num? value = num.tryParse(val);
                        if (value == null || value <= 0) return 'Cân nặng không hợp lệ';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => _recalculateBmi(),
                      decoration: const InputDecoration(labelText: 'Chiều cao (cm)'),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Nhập chiều cao';
                        final num? value = num.tryParse(val);
                        if (value == null || value <= 0) return 'Chiều cao không hợp lệ';
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _targetWeightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Cân nặng mục tiêu (kg, có thể để trống)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  initialValue: _activityFactor,
                  decoration: const InputDecoration(labelText: 'Mức độ vận động'),
                  items: const [
                    DropdownMenuItem(value: 1.2, child: Text('Ít vận động (1.2)')),
                    DropdownMenuItem(value: 1.375, child: Text('Vận động nhẹ (1.375)')),
                    DropdownMenuItem(value: 1.55, child: Text('Vận động vừa (1.55)')),
                    DropdownMenuItem(value: 1.725, child: Text('Vận động nhiều (1.725)')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _activityFactor = v);
                  },
                ),
                const SizedBox(height: 16),

                // BMI box + cảnh báo gợi ý (nếu có)
                if (_bmi != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Chỉ số cơ thể (BMI)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('BMI: ${_bmi!.toStringAsFixed(1)} – $_bmiStatus'),
                      const SizedBox(height: 8),
                      // Cảnh báo/khuyến nghị nổi bật
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (_bmiStatus == 'Bình thường') ? Colors.green.shade50 : Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: (_bmiStatus == 'Bình thường') ? Colors.green.shade200 : Colors.orange.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              (_bmiStatus == 'Bình thường') ? Icons.check_circle : Icons.warning_amber_rounded,
                              color: (_bmiStatus == 'Bình thường') ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_bmiAdvice)),
                          ],
                        ),
                      ),
                    ]),
                  ),

                // --- ĐÃ BỎ HIỂN THỊ khung BMR/TDEE/macros theo yêu cầu ---
                // (Vẫn tính và lưu lên Firestore nhưng không hiển thị ở đây)

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    child: const Text('Hoàn tất & Bắt đầu sử dụng', style: TextStyle(fontSize: 16)),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
