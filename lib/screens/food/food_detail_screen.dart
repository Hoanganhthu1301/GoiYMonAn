import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../services/like_service.dart';
import '../profile/profile_screen.dart';
import '../../widgets/download_recipe_button.dart';
import '../../widgets/comment_section.dart';
import '../../services/intake_service.dart';

class FoodDetailScreen extends StatefulWidget {
  final String foodId;
  const FoodDetailScreen({super.key, required this.foodId});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  VideoPlayerController? _videoController;
  String instructions = '';
  String categoryType = '';
  late LikeService _likeSvc;
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  // New fields for scrolling and comment input (if CommentSection needs scrolling focus)
  final ScrollController _scrollController = ScrollController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _likeSvc = context.read<LikeService>();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _setupVideo(String videoUrl) {
    if (videoUrl.isNotEmpty) {
      _videoController ??= VideoPlayerController.networkUrl(Uri.parse(videoUrl))
        ..initialize().then((_) {
          setState(() {});
        });
    }
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  void _seekBy(Duration offset) {
    if (_videoController == null) return;
    final pos = _videoController!.value.position;
    final dur = _videoController!.value.duration;
    var target = pos + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (target > dur) target = dur;
    _videoController!.seekTo(target);
  }

  void _changeSpeed(double delta) {
    if (_videoController == null) return;
    final curSpeed = _videoController!.value.playbackSpeed;
    _videoController!.setPlaybackSpeed((curSpeed + delta).clamp(0.25, 3.0));
    setState(() {});
  }

  void _scrollToComments() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chi tiết món ăn"),
        actions: [DownloadRecipeButton(foodId: widget.foodId)],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('foods')
            .doc(widget.foodId)
            .get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Không tìm thấy món ăn"));
          }
          final data = snapshot.data!.data()!;
          final imageUrl = data['image_url'] ?? '';
          final name = data['name'] ?? '';
          final calories = data['calories']?.toString() ?? '0';
          final diet = data['dietName'] ?? '';
          final categoryId = data['categoryId'] ?? '';

          if (categoryId.isNotEmpty && categoryType.isEmpty) {
            FirebaseFirestore.instance
                .collection('categories')
                .doc(categoryId)
                .get()
                .then((catSnap) {
                  if (catSnap.exists) {
                    setState(() {
                      categoryType = catSnap.data()?['name'] ?? '';
                    });
                  }
                });
          }
          // loại hình món ăn
          final videoUrl = data['video_url'] ?? '';
          final ingredients = data['ingredients'] ?? '';

          // --- Hướng dẫn nấu ---
          final instrData = data['instructions'];
          if (instrData != null) {
            if (instrData is String) {
              instructions = instrData;
            } else if (instrData is List<dynamic>) {
              instructions = instrData.join("\n");
            }
          }

          // --- Người đăng ---
          final authorId =
              data['authorId'] ?? data['uid'] ?? data['userId'] ?? '';
          final authorNameFb = data['authorName'] ?? 'Người dùng';
          final authorPhotoURLFb = data['authorPhotoURL'] ?? '';

          // --- Setup video ---
          if (_videoController == null && videoUrl.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _setupVideo(videoUrl);
            });
          }

          // Build content and include CommentSection at the end
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Ảnh món ăn
                      imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              width: double.infinity,
                              height: 240,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              width: double.infinity,
                              height: 200,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.fastfood, size: 80),
                            ),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // ❤️ Yêu thích
                                StreamBuilder<bool>(
                                  stream: _likeSvc.isLikedStream(widget.foodId),
                                  initialData: false,
                                  builder: (context, s) {
                                    final liked = s.data ?? false;
                                    return IconButton(
                                      tooltip: liked ? 'Bỏ thích' : 'Thích',
                                      onPressed: uid == null
                                          ? null
                                          : () => _likeSvc.toggleLike(
                                              widget.foodId,
                                              liked,
                                            ),
                                      icon: Icon(
                                        liked
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: liked
                                            ? Colors.pink
                                            : Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Đi tới bình luận',
                                  onPressed: _scrollToComments,
                                  icon: const Icon(
                                    Icons.comment,
                                    color: Colors.grey,
                                  ),
                                ),
                                // 🔖 Lưu món
                                StreamBuilder<bool>(
                                  stream: _likeSvc.isSavedStream(widget.foodId),
                                  initialData: false,
                                  builder: (context, s) {
                                    final saved = s.data ?? false;
                                    return IconButton(
                                      tooltip: saved ? 'Bỏ lưu' : 'Lưu',
                                      onPressed: uid == null
                                          ? null
                                          : () => _likeSvc.toggleSave(
                                              widget.foodId,
                                              saved,
                                            ),
                                      icon: Icon(
                                        saved
                                            ? Icons.bookmark
                                            : Icons.bookmark_border,
                                        color: saved
                                            ? Colors.blue
                                            : Colors.grey,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text("Calo: $calories kcal"),
                            const SizedBox(height: 8),
                            // === Nút ghi nhận món đã ăn ===
                            ElevatedButton.icon(
                              onPressed: uid == null
                                  ? null
                                  : () async {
                                      final kcal = (data['calories'] ?? 0)
                                          .toDouble();
                                      final name = data['name'] ?? '';

                                      await IntakeService().addConsumption(
                                        uid: uid!,
                                        foodId: widget.foodId,
                                        foodName: name,
                                        calories: kcal,
                                        portions: 1,
                                      );

                                      if (!mounted) return;

                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            "Đã ghi nhận: $name (+$kcal kcal)",
                                          ),
                                        ),
                                      );
                                    },
                              icon: const Icon(Icons.restaurant),
                              label: const Text('Tôi đã ăn món này'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),

                            if (diet.isNotEmpty) Text("Chế độ ăn: $diet"),
                            if (categoryType.isNotEmpty)
                              Text("Loại món ăn: $categoryType"),
                            const SizedBox(height: 16),

                            // Người đăng
                            _AuthorSection(
                              authorId: authorId,
                              fallbackName: authorNameFb,
                              fallbackPhotoURL: authorPhotoURLFb,
                            ),

                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 12),

                            // Nguyên liệu
                            const Text(
                              "Nguyên liệu:",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ingredients,
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),
                            const SizedBox(height: 16),

                            // Hướng dẫn nấu
                            const Text(
                              "Hướng dẫn nấu:",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              instructions.isNotEmpty
                                  ? instructions
                                  : "Chưa có hướng dẫn.",
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),

                      // Video
                      if (_videoController != null &&
                          _videoController!.value.isInitialized)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            children: [
                              AspectRatio(
                                aspectRatio:
                                    _videoController!.value.aspectRatio,
                                child: VideoPlayer(_videoController!),
                              ),
                              VideoProgressIndicator(
                                _videoController!,
                                allowScrubbing: true,
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.replay_10),
                                    onPressed: () =>
                                        _seekBy(const Duration(seconds: -10)),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      _videoController!.value.isPlaying
                                          ? Icons.pause
                                          : Icons.play_arrow,
                                    ),
                                    onPressed: _togglePlayPause,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.forward_10),
                                    onPressed: () =>
                                        _seekBy(const Duration(seconds: 10)),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.fast_forward),
                                    onPressed: () => _changeSpeed(0.25),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.fast_rewind),
                                    onPressed: () => _changeSpeed(-0.25),
                                  ),
                                  Text(
                                    '${_videoController!.value.playbackSpeed.toStringAsFixed(2)}x',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),

                      const SizedBox(height: 12),

                      // Comments header with quick scroll button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Bình luận',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Insert the CommentSection widget here
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: CommentSection(foodId: widget.foodId),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),

              // If you want a persistent input at bottom separate from CommentSection,
              // you can add it here. CommentSection is expected to include input by default.
            ],
          );
        },
      ),
    );
  }
}

class _AuthorSection extends StatelessWidget {
  final String authorId;
  final String fallbackName;
  final String fallbackPhotoURL;

  const _AuthorSection({
    required this.authorId,
    required this.fallbackName,
    required this.fallbackPhotoURL,
  });

  @override
  Widget build(BuildContext context) {
    if (authorId.isEmpty) {
      return Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: fallbackPhotoURL.isNotEmpty
                ? NetworkImage(fallbackPhotoURL)
                : null,
            child: fallbackPhotoURL.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fallbackName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text(
                'Người đăng',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      );
    }

    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(authorId)
        .snapshots();

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProfileScreen(userId: authorId)),
        );
      },
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDocStream,
        builder: (context, snap) {
          final data = snap.data?.data();
          final displayName = (data?['displayName'] ?? '').toString().trim();
          final photoURL = (data?['photoURL'] ?? '').toString().trim();

          final nameToShow = displayName.isNotEmpty
              ? displayName
              : fallbackName;
          final photoToShow = photoURL.isNotEmpty ? photoURL : fallbackPhotoURL;

          return Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: photoToShow.isNotEmpty
                    ? NetworkImage(photoToShow)
                    : null,
                child: photoToShow.isEmpty ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nameToShow,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Người đăng',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              const Spacer(),
              const Icon(Icons.chevron_right),
            ],
          );
        },
      ),
    );
  }
}
