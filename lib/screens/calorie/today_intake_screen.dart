// lib/screens/intake/today_intake_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/intake_service.dart';

class TodayIntakeScreen extends StatefulWidget {
  const TodayIntakeScreen({super.key});

  @override
  State<TodayIntakeScreen> createState() => _TodayIntakeScreenState();
}

class _TodayIntakeScreenState extends State<TodayIntakeScreen> {
  late final String uid;
  DateTime _selectedDate = DateTime.now();

  final TextEditingController _weightController = TextEditingController();
  bool _savingWeight = false;

  // Hiện / ẩn toàn bộ danh sách món (mặc định: chỉ 3 món)
  bool _showAllMeals = false;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _saveWeight() async {
    final text = _weightController.text.trim();

    if (text.isEmpty || double.tryParse(text) == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Nhập cân nặng hợp lệ")));
      return;
    }

    final weight = double.parse(text);
    final month = DateTime.now().month;
    final year = DateTime.now().year;

    setState(() => _savingWeight = true);

    try {
      await IntakeService().saveWeight(
        uid: uid,
        weight: weight,
        month: month,
        year: year,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã lưu cân nặng")));
      _weightController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Không lưu được: $e")));
    } finally {
      if (mounted) {
        setState(() => _savingWeight = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final intakeService = IntakeService();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nhật ký ăn uống"),
        backgroundColor: Colors.green,
      ),
      body: StreamBuilder<List<Consumption>>(
        stream: intakeService.allConsumptionsStream(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapshot.data!;

          // danh sách món theo ngày đang chọn
          final dayList = all
              .where((c) => _isSameDay(c.consumedAt, _selectedDate))
              .toList();

          final totalDay = dayList.fold<double>(
            0,
            (prev, c) => prev + c.calories,
          );

          // dữ liệu cho biểu đồ calo 7 ngày gần nhất
          final now = DateTime.now();
          final caloriesByDay = intakeService.caloriesByDay(all);
          final List<DateTime> last7Days = List.generate(7, (i) {
            final d = now.subtract(Duration(days: 6 - i));
            return DateTime(d.year, d.month, d.day);
          });

          return Container(
            color: Colors.green.shade50,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ===== CHỌN NGÀY =====
                  GestureDetector(
                    onTap: _pickDate,
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                "Ngày: ${_selectedDate.day.toString().padLeft(2, '0')}/"
                                "${_selectedDate.month.toString().padLeft(2, '0')}/"
                                "${_selectedDate.year}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.edit_calendar,
                              color: Colors.green,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ===== TỔNG CALO NGÀY NÀY =====
                  Card(
                    color: Colors.green.shade100,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Tổng calo ngày này",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "${totalDay.toStringAsFixed(0)} kcal",
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ===== DANH SÁCH MÓN TRONG NGÀY (giới hạn 3 + xem thêm) =====
                  // ===== DANH SÁCH MÓN TRONG NGÀY =====
                  Text(
                    "Món đã ăn trong ngày",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  if (dayList.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text("Ngày này bạn chưa ghi món nào."),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: [
                        // Hiển thị tối đa 3 món
                        ...List.generate(
                          _showAllMeals
                              ? dayList.length
                              : (dayList.length > 3 ? 3 : dayList.length),
                          (i) {
                            final c = dayList[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(13),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.green.shade300,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.restaurant_menu,
                                    color: Colors.green,
                                    size: 24,
                                  ),
                                ),
                                title: Text(
                                  c.foodName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Row(
                                  children: [
                                    Icon(
                                      Icons.local_fire_department,
                                      color: Colors.orange,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${c.calories.toStringAsFixed(0)} kcal",
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(Icons.access_time, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      "${c.consumedAt.hour.toString().padLeft(2, '0')}:"
                                      "${c.consumedAt.minute.toString().padLeft(2, '0')}",
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        if (dayList.length > 3)
                          TextButton(
                            onPressed: () =>
                                setState(() => _showAllMeals = !_showAllMeals),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.green.shade200,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _showAllMeals ? "Thu gọn" : "Xem thêm",
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Icon(
                                  _showAllMeals
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.green.shade800,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                  const SizedBox(height: 20),

                  // ===== BIỂU ĐỒ CALO 7 NGÀY =====
                  Text(
                    "Biểu đồ calo 7 ngày gần nhất",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final i = value.toInt();
                                    if (i < 0 || i >= last7Days.length) {
                                      return const SizedBox.shrink();
                                    }
                                    final d = last7Days[i];
                                    return Text(
                                      "${d.day}/${d.month}",
                                      style: const TextStyle(fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                            ),
                            lineBarsData: [
                              LineChartBarData(
                                isCurved: true,
                                barWidth: 3,
                                color: Colors.green,
                                dotData: FlDotData(show: true),
                                spots: List.generate(last7Days.length, (i) {
                                  final d = last7Days[i];
                                  final key = DateTime(d.year, d.month, d.day);
                                  return FlSpot(
                                    i.toDouble(),
                                    caloriesByDay[key] ?? 0,
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ===== BIỂU ĐỒ CÂN NẶNG THEO THÁNG + Ô NHẬP CÂN NẶNG (bên dưới) =====
                  Text(
                    "Biểu đồ cân nặng theo tháng",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),

                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection("users")
                        .doc(uid)
                        .collection("weights")
                        .where("year", isEqualTo: DateTime.now().year)
                        .snapshots(),
                    builder: (context, snapW) {
                      if (!snapW.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapW.data!.docs;

                      // Không có dữ liệu cân nặng nào trong năm
                      if (docs.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Card(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: Text(
                                    "Chưa có dữ liệu cân nặng.\nHãy nhập cân nặng tháng này.",
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildWeightInputCard(enable: true),
                          ],
                        );
                      }

                      // map tháng -> cân nặng
                      final Map<int, double> weightMap = {};
                      final List<Map<String, dynamic>> rows = [];

                      for (var d in docs) {
                        final data = d.data();
                        final m = (data["month"] ?? 0) as int;
                        final y = (data["year"] ?? DateTime.now().year) as int;
                        final w = (data["weight"] ?? 0).toDouble();
                        if (m >= 1 && m <= 12 && w > 0) {
                          weightMap[m] = w;
                        }

                        DateTime date;
                        if (data["updatedAt"] is Timestamp) {
                          date = (data["updatedAt"] as Timestamp).toDate();
                        } else {
                          date = DateTime(y, m, 1);
                        }
                        rows.add({
                          "month": m,
                          "year": y,
                          "weight": w,
                          "date": date,
                        });
                      }

                      // sort theo thời gian để lấy mới nhất / trước đó
                      rows.sort(
                        (a, b) => (a["date"] as DateTime).compareTo(
                          b["date"] as DateTime,
                        ),
                      );

                      final latest = rows.last;
                      final double latestWeight = (latest["weight"] as num)
                          .toDouble();
                      final DateTime latestDate = latest["date"] as DateTime;

                      double? prevWeight;
                      if (rows.length > 1) {
                        prevWeight = (rows[rows.length - 2]["weight"] as num)
                            .toDouble();
                      }

                      final double diffKg = prevWeight != null
                          ? latestWeight - prevWeight
                          : 0.0;
                      final double diffPercent =
                          (prevWeight != null && prevWeight != 0)
                          ? diffKg / prevWeight * 100
                          : 0.0;

                      String fmtKg(double v) =>
                          "${v > 0 ? "+" : ""}${v.toStringAsFixed(1)} kg";
                      String fmtPercent(double v) =>
                          "${v > 0 ? "+" : ""}${v.toStringAsFixed(1)}%";

                      // forward-fill cho 12 tháng
                      double? lastW;
                      final List<FlSpot> spots = [];
                      for (int m = 1; m <= 12; m++) {
                        if (weightMap[m] != null) {
                          lastW = weightMap[m];
                        }
                        if (lastW != null) {
                          spots.add(FlSpot(m.toDouble(), lastW));
                        }
                      }

                      final int currentMonth = DateTime.now().month;
                      final bool hasThisMonth = weightMap[currentMonth] != null;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Card chứa A + B + biểu đồ
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _smallInfoCard(
                                          title: "Cân nặng mới nhất",
                                          value:
                                              "${latestWeight.toStringAsFixed(1)} kg",
                                          sub:
                                              "${latestDate.day.toString().padLeft(2, '0')}/${latestDate.month.toString().padLeft(2, '0')}",
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _smallInfoCard(
                                          title: "Cân nặng trước đó",
                                          value: prevWeight != null
                                              ? "${prevWeight.toStringAsFixed(1)} kg"
                                              : "--",
                                          sub: "",
                                          color: Colors.blueGrey,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _smallInfoCard(
                                          title: "Chênh lệch",
                                          value: fmtKg(diffKg),
                                          sub: fmtPercent(diffPercent),
                                          color: diffKg <= 0
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    height: 180,
                                    child: LineChart(
                                      LineChartData(
                                        gridData: FlGridData(show: true),
                                        titlesData: FlTitlesData(
                                          bottomTitles: AxisTitles(
                                            sideTitles: SideTitles(
                                              showTitles: true,
                                              interval: 1,
                                              getTitlesWidget: (value, meta) {
                                                if (value < 1 || value > 12) {
                                                  return const SizedBox.shrink();
                                                }
                                                return Text(
                                                  "T${value.toInt()}",
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        lineBarsData: [
                                          LineChartBarData(
                                            isCurved: true,
                                            barWidth: 3,
                                            color: Colors.green,
                                            dotData: FlDotData(show: true),
                                            spots: spots,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Ô nhập cân nặng bên dưới
                          if (!hasThisMonth)
                            _buildWeightInputCard(enable: true),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // card nhỏ cho phần cân nặng (A + B + chênh lệch)
  Widget _smallInfoCard({
    required String title,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 10)),
          ],
        ],
      ),
    );
  }

  // Card nhập cân nặng (tháng này)
  Widget _buildWeightInputCard({required bool enable}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              "Cập nhật cân nặng tháng này",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _weightController,
              keyboardType: TextInputType.number,
              enabled: enable && !_savingWeight,
              decoration: const InputDecoration(
                labelText: "Nhập cân nặng (kg)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: (!enable || _savingWeight) ? null : _saveWeight,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: _savingWeight
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Lưu cân nặng",
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Card báo đã có cân nặng tháng này (khỏi nhập nữa – kiểu "chìm")
}
