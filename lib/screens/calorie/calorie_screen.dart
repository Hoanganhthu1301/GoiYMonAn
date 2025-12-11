// import 'package:flutter/material.dart';
// //import 'package:firebase_auth/firebase_auth.dart';
// //import 'package:cloud_firestore/cloud_firestore.dart';
// import '../../services/calorie_service.dart';

// class CalorieScreen extends StatefulWidget {
//   const CalorieScreen({super.key});

//   @override
//   State<CalorieScreen> createState() => _CalorieScreenState();
// }

// class _CalorieScreenState extends State<CalorieScreen> {
//   final _weightController = TextEditingController(); // kg
//   final _heightController = TextEditingController(); // cm
//   final _ageController = TextEditingController();

//   String _gender = 'female'; // male / female
//   double _activityFactor = 1.2;
//   String _goal = 'maintain'; // lose / gain / maintain

//   int? _bmr;
//   int? _tdee;
//   int? _dailyGoal;
//   bool _saving = false;

//   final _formKey = GlobalKey<FormState>();

//   @override
//   void dispose() {
//     _weightController.dispose();
//     _heightController.dispose();
//     _ageController.dispose();
//     super.dispose();
//   }

//   void _calculate() async {
//     if (!_formKey.currentState!.validate()) return;

//     final weight = double.parse(_weightController.text);
//     final height = double.parse(_heightController.text);
//     final age = int.parse(_ageController.text);

//     // Công thức Mifflin-St Jeor
//     double bmr;
//     if (_gender == 'male') {
//       bmr = 10 * weight + 6.25 * height - 5 * age + 5;
//     } else {
//       bmr = 10 * weight + 6.25 * height - 5 * age - 161;
//     }

//     final tdee = bmr * _activityFactor;

//     double goal = tdee;
//     if (_goal == 'lose') {
//       goal = tdee - 500; // giảm cân
//     } else if (_goal == 'gain') {
//       goal = tdee + 500; // tăng cân
//     }

//     setState(() {
//       _bmr = bmr.round();
//       _tdee = tdee.round();
//       _dailyGoal = goal.round().clamp(800, 6000); // giới hạn cho an toàn
//     });

//     // LƯU XUỐNG FIRESTORE
//     try {
//       setState(() => _saving = true);
//       await CalorieService.instance.saveDailyGoal(
//         bmr: _bmr!,
//         tdee: _tdee!,
//         dailyGoal: _dailyGoal!,
//       );
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Đã lưu mục tiêu calo hằng ngày')),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text('Lỗi lưu dữ liệu: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => _saving = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Tính calo'),
//         backgroundColor: Colors.green,
//       ),
//       body: SafeArea(
//         child: Padding(
//           padding: const EdgeInsets.all(16),
//           child: SingleChildScrollView(
//             child: Center(
//               child: ConstrainedBox(
//                 constraints: const BoxConstraints(maxWidth: 400),
//                 child: Card(
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(16),
//                   ),
//                   elevation: 2,
//                   child: Padding(
//                     padding: const EdgeInsets.all(16),
//                     child: Form(
//                       key: _formKey,
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         crossAxisAlignment: CrossAxisAlignment.stretch,
//                         children: [
//                           const Text(
//                             'Tính nhu cầu calo',
//                             textAlign: TextAlign.center,
//                             style: TextStyle(
//                               fontSize: 20,
//                               fontWeight: FontWeight.bold,
//                             ),
//                           ),
//                           const SizedBox(height: 16),
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: TextFormField(
//                                   controller: _weightController,
//                                   keyboardType:
//                                       const TextInputType.numberWithOptions(
//                                         decimal: true,
//                                       ),
//                                   decoration: const InputDecoration(
//                                     labelText: 'Cân nặng (kg)',
//                                   ),
//                                   validator: (v) {
//                                     if (v == null || v.isEmpty) {
//                                       return 'Nhập cân nặng';
//                                     }
//                                     final x = double.tryParse(v);
//                                     if (x == null || x <= 0) {
//                                       return 'Giá trị không hợp lệ';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                               ),
//                               const SizedBox(width: 16),
//                               Expanded(
//                                 child: TextFormField(
//                                   controller: _heightController,
//                                   keyboardType:
//                                       const TextInputType.numberWithOptions(
//                                         decimal: true,
//                                       ),
//                                   decoration: const InputDecoration(
//                                     labelText: 'Chiều cao (cm)',
//                                   ),
//                                   validator: (v) {
//                                     if (v == null || v.isEmpty) {
//                                       return 'Nhập chiều cao';
//                                     }
//                                     final x = double.tryParse(v);
//                                     if (x == null || x <= 0) {
//                                       return 'Giá trị không hợp lệ';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 12),
//                           Row(
//                             children: [
//                               Expanded(
//                                 child: TextFormField(
//                                   controller: _ageController,
//                                   keyboardType:
//                                       const TextInputType.numberWithOptions(),
//                                   decoration: const InputDecoration(
//                                     labelText: 'Tuổi',
//                                   ),
//                                   validator: (v) {
//                                     if (v == null || v.isEmpty) {
//                                       return 'Nhập tuổi';
//                                     }
//                                     final x = int.tryParse(v);
//                                     if (x == null || x <= 0) {
//                                       return 'Không hợp lệ';
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                               ),
//                               const SizedBox(width: 16),
//                               Expanded(
//                                 child: DropdownButtonFormField<String>(
//                                   initialValue:
//                                       _gender, // sửa từ value → initialValue
//                                   decoration: const InputDecoration(
//                                     labelText: 'Giới tính',
//                                   ),
//                                   items: const [
//                                     DropdownMenuItem(
//                                       value: 'female',
//                                       child: Text('Nữ'),
//                                     ),
//                                     DropdownMenuItem(
//                                       value: 'male',
//                                       child: Text('Nam'),
//                                     ),
//                                   ],
//                                   onChanged: (v) {
//                                     if (v == null) return;
//                                     setState(() => _gender = v);
//                                   },
//                                 ),
//                               ),
//                             ],
//                           ),
//                           const SizedBox(height: 12),
//                           DropdownButtonFormField<double>(
//                             initialValue: _activityFactor, // sửa
//                             decoration: const InputDecoration(
//                               labelText: 'Mức hoạt động',
//                             ),
//                             items: const [
//                               DropdownMenuItem(
//                                 value: 1.2,
//                                 child: Text('Ít vận động (1.2)'),
//                               ),
//                               DropdownMenuItem(
//                                 value: 1.375,
//                                 child: Text('Vận động nhẹ (1.375)'),
//                               ),
//                               DropdownMenuItem(
//                                 value: 1.55,
//                                 child: Text('Vận động vừa (1.55)'),
//                               ),
//                               DropdownMenuItem(
//                                 value: 1.725,
//                                 child: Text('Vận động nhiều (1.725)'),
//                               ),
//                             ],
//                             onChanged: (v) {
//                               if (v == null) return;
//                               setState(() => _activityFactor = v);
//                             },
//                           ),

//                           const SizedBox(height: 12),
//                           DropdownButtonFormField<String>(
//                             initialValue: _goal,
//                             decoration: const InputDecoration(
//                               labelText: 'Mục tiêu',
//                             ),
//                             items: const [
//                               DropdownMenuItem(
//                                 value: 'lose',
//                                 child: Text('Giảm cân'),
//                               ),
//                               DropdownMenuItem(
//                                 value: 'maintain',
//                                 child: Text('Giữ cân'),
//                               ),
//                               DropdownMenuItem(
//                                 value: 'gain',
//                                 child: Text('Tăng cân'),
//                               ),
//                             ],
//                             onChanged: (v) {
//                               if (v == null) return;
//                               setState(() => _goal = v);
//                             },
//                           ),
//                           const SizedBox(height: 16),
//                           Center(
//                             child: ElevatedButton(
//                               onPressed: _saving ? null : _calculate,
//                               child: _saving
//                                   ? const SizedBox(
//                                       width: 18,
//                                       height: 18,
//                                       child: CircularProgressIndicator(
//                                         strokeWidth: 2,
//                                       ),
//                                     )
//                                   : const Text('Tính'),
//                             ),
//                           ),
//                           const SizedBox(height: 16),
//                           if (_bmr != null) ...[
//                             Text(
//                               'BMR: $_bmr kcal',
//                               textAlign: TextAlign.center,
//                             ),
//                             Text(
//                               'TDEE: $_tdee kcal',
//                               textAlign: TextAlign.center,
//                             ),
//                             Text(
//                               'Mục tiêu hằng ngày: $_dailyGoal kcal',
//                               textAlign: TextAlign.center,
//                             ),
//                           ],
//                         ],
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
