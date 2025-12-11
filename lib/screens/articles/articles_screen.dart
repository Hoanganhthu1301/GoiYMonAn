import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';


class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  static const Color primaryGreen = Color(0xFF4CAF50);
  static const Color softGreen = Color(0xFFE8F5E9);

  // Thêm đây:
  final ValueNotifier<bool> _isDarkMode = ValueNotifier(false);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _isDarkMode,
      builder: (context, isDark, child) {
        final backgroundColor = isDark ? Colors.grey[850] : softGreen;
        final textColor = isDark ? Colors.white : Colors.black87;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text('Bài viết của tôi'),
            centerTitle: true,
            backgroundColor: isDark ? Colors.black87 : Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: textColor),
            titleTextStyle: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            actions: [
              IconButton(
                icon: Icon(isDark ? Icons.wb_sunny : Icons.dark_mode, color: textColor),
                onPressed: () => _isDarkMode.value = !_isDarkMode.value,
              )
            ],
          ),
          body: _currentUserId == null
              ? Center(child: Text('Vui lòng đăng nhập', style: TextStyle(color: textColor)))
              : StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('articles')
                      .where('authorId', isEqualTo: _currentUserId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];

                    if (docs.isEmpty) {
                      return Center(
                        child: Text('Bạn chưa có bài viết nào', style: TextStyle(color: textColor)),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final title = data['title'] ?? 'Không có tiêu đề';
                        final content = data['content'] ?? '';
                        final createdAt = (data['createdAt'] as Timestamp?)
                                ?.toDate()
                                .toString()
                                .split('.')
                                .first ??
                            'N/A';
                        final imageUrl = data['imageUrl'] ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _showArticleDetail(context, data, title, isDark),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            width: 70,
                                            height: 70,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 70,
                                            height: 70,
                                            color: backgroundColor,
                                            child: const Icon(Icons.article),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          content.length > 80
                                              ? '${content.substring(0, 80)}...'
                                              : content,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: textColor.withOpacity(0.8),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: primaryGreen.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: const Text(
                                                'Chỉ mình tôi',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: primaryGreen,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              createdAt,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  void _showArticleDetail(BuildContext context, Map<String, dynamic> data, String title, bool isDark) {
    final textColor = isDark ? Colors.white : Colors.black87;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      color: textColor,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if ((data['imageUrl'] ?? '').toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        data['imageUrl'],
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  data['content'] ?? '',
                  style: TextStyle(fontSize: 15, height: 1.5, color: textColor),
                ),
                const SizedBox(height: 12),
                Text(
                  'Đăng lúc: ${(data['createdAt'] as Timestamp?)?.toDate().toString().split('.').first ?? 'N/A'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}