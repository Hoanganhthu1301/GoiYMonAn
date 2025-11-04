import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import '../../services/like_service.dart';
import '../profile/profile_screen.dart';
import '../../widgets/download_recipe_button.dart';
import '../../widgets/comment_section.dart';

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

  // ⚡ Thay đổi tốc độ video
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
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        title: const Text("Chi tiết món ăn", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
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
          final videoUrl = data['video_url'] ?? '';
          final ingredients = data['ingredients'] ?? '';

          final instrData = data['instructions'];
          if (instrData is String){ 
            instructions = instrData;
          }
          else if (instrData is List) { 
            instructions = instrData.join("\n");}

          if (categoryId.isNotEmpty && categoryType.isEmpty) {
            FirebaseFirestore.instance.collection('categories').doc(categoryId).get().then((catSnap) {
              if (catSnap.exists) {
                setState(() => categoryType = catSnap.data()?['name'] ?? '');
              }
            });
          }

          final authorId = data['authorId'] ?? data['uid'] ?? '';
          final authorNameFb = data['authorName'] ?? 'Người dùng';
          final authorPhotoURLFb = data['authorPhotoURL'] ?? '';

          if (_videoController == null && videoUrl.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _setupVideo(videoUrl));
          }

          return SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ảnh món ăn
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, width: double.infinity, height: 240, fit: BoxFit.cover)
                      : Container(
                          width: double.infinity,
                          height: 220,
                          color: Colors.green.shade100,
                          child: const Icon(Icons.fastfood, size: 80, color: Colors.green),
                        ),
                ),
                const SizedBox(height: 16),

                // Tên món
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(height: 8),

                // Calo, chế độ ăn, loại món ăn (mỗi dòng riêng)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Calo: $calories kcal", style: const TextStyle(fontSize: 16)),
                    if (diet.isNotEmpty) Text("Chế độ ăn: $diet", style: const TextStyle(fontSize: 16)),
                    if (categoryType.isNotEmpty)
                      Text("Loại món ăn: $categoryType", style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 12),

                // Tim, bình luận, lưu
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    StreamBuilder<bool>(
                      stream: _likeSvc.isLikedStream(widget.foodId),
                      initialData: false,
                      builder: (context, s) {
                        final liked = s.data ?? false;
                        return IconButton(
                          icon: Icon(
                            liked ? Icons.favorite : Icons.favorite_border,
                            color: liked ? Colors.pink : Colors.grey,
                          ),
                          onPressed: uid == null ? null : () => _likeSvc.toggleLike(widget.foodId, liked),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.comment, color: Colors.grey),
                      onPressed: _scrollToComments,
                    ),
                    StreamBuilder<bool>(
                      stream: _likeSvc.isSavedStream(widget.foodId),
                      initialData: false,
                      builder: (context, s) {
                        final saved = s.data ?? false;
                        return IconButton(
                          icon: Icon(
                            saved ? Icons.bookmark : Icons.bookmark_border,
                            color: saved ? Colors.green : Colors.grey,
                          ),
                          onPressed: uid == null ? null : () => _likeSvc.toggleSave(widget.foodId, saved),
                        );
                      },
                    ),
                  ],
                ),
                const Divider(),

                // Người đăng
                _AuthorSection(
                  authorId: authorId,
                  fallbackName: authorNameFb,
                  fallbackPhotoURL: authorPhotoURLFb,
                ),
                const SizedBox(height: 16),

                // Nguyên liệu
                Text(
                  "Nguyên liệu",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                ),
                const SizedBox(height: 6),
                Text(ingredients, style: const TextStyle(fontSize: 16, height: 1.5)),

                const SizedBox(height: 16),

                // Hướng dẫn
                Text(
                  " Hướng dẫn nấu",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                ),
                const SizedBox(height: 6),
                Text(
                  instructions.isNotEmpty ? instructions : "Chưa có hướng dẫn.",
                  style: const TextStyle(fontSize: 16, height: 1.5),
                ),

                const SizedBox(height: 16),

                // Video (có điều chỉnh tốc độ)
                if (_videoController != null && _videoController!.value.isInitialized)
                  Column(
                    children: [
                      AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: VideoPlayer(_videoController!),
                        ),
                      ),
                      VideoProgressIndicator(_videoController!, allowScrubbing: true),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(icon: const Icon(Icons.replay_10), onPressed: () => _seekBy(const Duration(seconds: -10))),
                          IconButton(
                            icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow),
                            onPressed: _togglePlayPause,
                          ),
                          IconButton(icon: const Icon(Icons.forward_10), onPressed: () => _seekBy(const Duration(seconds: 10))),
                          IconButton(icon: const Icon(Icons.fast_rewind), onPressed: () => _changeSpeed(-0.25)),
                          IconButton(icon: const Icon(Icons.fast_forward), onPressed: () => _changeSpeed(0.25)),
                          Text('${_videoController!.value.playbackSpeed.toStringAsFixed(2)}x'),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),

                // Bình luận
                const Divider(),
                Text(
                  " Bình luận",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                ),
                const SizedBox(height: 8),
                CommentSection(foodId: widget.foodId),
              ],
            ),
          );
        },
      ),
    );
  }
}

// 👤 Người đăng
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
      return _buildTile(fallbackName, fallbackPhotoURL);
    }

    final userDocStream = FirebaseFirestore.instance.collection('users').doc(authorId).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userDocStream,
      builder: (context, snap) {
        final data = snap.data?.data();
        final displayName = (data?['displayName'] ?? '').toString().trim();
        final photoURL = (data?['photoURL'] ?? '').toString().trim();

        return InkWell(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: authorId))),
          child: _buildTile(displayName.isNotEmpty ? displayName : fallbackName, photoURL.isNotEmpty ? photoURL : fallbackPhotoURL),
        );
      },
    );
  }

  Widget _buildTile(String name, String photoURL) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: photoURL.isNotEmpty ? NetworkImage(photoURL) : null,
          backgroundColor: Colors.green.withValues(alpha: 0.2),
          child: photoURL.isEmpty ? const Icon(Icons.person, color: Colors.green) : null,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Text('Người đăng', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        const Spacer(),
        const Icon(Icons.chevron_right, color: Colors.grey),
      ],
    );
  }
}
