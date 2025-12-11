// lib/screens/food/food_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../services/like_service.dart';
import '../../services/intake_service.dart';
import '../../widgets/download_recipe_button.dart';
import '../../widgets/comment_section.dart';
import '../profile/profile_screen.dart';

class FoodDetailScreen extends StatefulWidget {
  final String foodId;
  const FoodDetailScreen({super.key, required this.foodId});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen>
    with SingleTickerProviderStateMixin {
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _foodFuture;
  VideoPlayerController? _videoController;
  String _instructions = '';
  String _categoryName = '';
  late LikeService _likeSvc;
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _animController;
  bool _commentsExpanded = false;
  
  Widget _previewCommentItem(Map<String, dynamic> doc) {
    final text = doc['text'] ?? '';
    final authorName = doc['authorName'] ?? 'Người dùng';
    final ts = doc['createdAt'];
    final id = doc['id'] ?? '';
    final authorId = doc['authorId'] ?? '';

    DateTime time;
    if (ts is Timestamp) {
      time = ts.toDate();
    } else if (ts is Map && ts['_seconds'] != null) {
      time = DateTime.fromMillisecondsSinceEpoch((ts['_seconds'] as int) * 1000);
    } else {
      time = DateTime.now();
    }

    final timeStr = timeago.format(time, locale: 'vi');

    final isOwner = authorId == _uid;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(authorName, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Text(text),
          const SizedBox(height: 6),
          Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
      trailing: isOwner
          ? IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 24),
              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
              onPressed: () => _confirmAndDeleteComment(id, authorId),
            )
          : null,
    );
  }

  Future<void> _confirmAndDeleteComment(String docId, String authorId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != authorId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bạn không có quyền xóa bình luận này')));
      }
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xác nhận'),
        content: const Text('Bạn có chắc muốn xóa bình luận này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa')),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await FirebaseFirestore.instance.collection('comments').doc(docId).delete();
      if (mounted) {
        setState(() {}); // rebuild so FutureBuilder re-fetches preview
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã xóa bình luận')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xóa thất bại: $e')));
    }
  }


  @override
  void initState() {
    super.initState();
    _foodFuture = FirebaseFirestore.instance
        .collection('foods')
        .doc(widget.foodId)
        .get();
    _animController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _likeSvc = context.read<LikeService>();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _videoInit(String videoUrl) {
    if (videoUrl.isEmpty) return;
    if (_videoController != null) return;
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    setState(() {
      final playing = _videoController!.value.isPlaying;
      playing ? _videoController!.pause() : _videoController!.play();
      _animController.forward().then((_) => _animController.reverse());
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
    final cur = _videoController!.value.playbackSpeed;
    final next = (cur + delta).clamp(0.25, 3.0);
    _videoController!.setPlaybackSpeed(next);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final primary = Colors.green.shade700;
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF6),
      appBar: AppBar(
        backgroundColor: primary,
        title: const Text("Chi tiết món ăn", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [DownloadRecipeButton(foodId: widget.foodId)],
      ),
      body: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: _foodFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Không tìm thấy món ăn"));
          }

          final data = snapshot.data!.data()!;
          final imageUrl = (data['image_url'] ?? '') as String;
          final name = (data['name'] ?? '') as String;
          final calories = (data['calories'] ?? 0).toString();
          final diet = (data['dietName'] ?? '') as String;
          final categoryId = (data['categoryId'] ?? '') as String;
          final videoUrl = (data['video_url'] ?? '') as String;
          final ingredients = (data['ingredients'] ?? '') as String;

          final instr = data['instructions'];
          if (instr is String) {
            _instructions = instr;
          } else if (instr is List) {
            _instructions = instr.join('\n');
          }

          // load category name once
          if (categoryId.isNotEmpty && _categoryName.isEmpty) {
            FirebaseFirestore.instance
                .collection('categories')
                .doc(categoryId)
                .get()
                .then((cat) {
              if (cat.exists && mounted) {
                setState(() => _categoryName = (cat.data()?['name'] ?? '') as String);
              }
            }).catchError((_) {});
          }

          final authorId = (data['authorId'] ?? data['uid'] ?? '') as String;
          final authorName = (data['authorName'] ?? 'Người dùng') as String;
          final authorPhoto = (data['authorPhotoURL'] ?? '') as String;

          if (_videoController == null && videoUrl.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _videoInit(videoUrl));
          }


          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
                        child: Image.network(imageUrl, width: double.infinity, height: 260, fit: BoxFit.cover),
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 240,
                        color: Colors.green.shade100,
                        child: const Icon(Icons.fastfood, size: 80, color: Colors.white),
                      ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              StreamBuilder<bool>(
                                stream: _likeSvc.isLikedStream(widget.foodId),
                                initialData: false,
                                builder: (c, s) {
                                  final liked = s.data ?? false;
                                  return IconButton(
                                    tooltip: liked ? 'Bỏ thích' : 'Thích',
                                    onPressed: _uid == null ? null : () => _likeSvc.toggleLike(widget.foodId, liked),
                                    icon: Icon(liked ? Icons.favorite : Icons.favorite_border, color: liked ? Colors.pink : Colors.grey),
                                  );
                                },
                              ),
                              StreamBuilder<bool>(
                                stream: _likeSvc.isSavedStream(widget.foodId),
                                initialData: false,
                                builder: (c, s) {
                                  final saved = s.data ?? false;
                                  return IconButton(
                                    tooltip: saved ? 'Bỏ lưu' : 'Lưu',
                                    onPressed: _uid == null ? null : () => _likeSvc.toggleSave(widget.foodId, saved),
                                    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: saved ? Colors.green : Colors.grey),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      Chip(
        avatar: const Icon(Icons.local_fire_department, color: Colors.orange),
        label: Text('${data['calories'] ?? 0} kcal'),
      ),
      Chip(
        // avatar: const Icon(Icons.fitness_center, color: Colors.blue),
        label: Text('Pro ${data['protein'] ?? 0} g '),
      ),
      Chip(
        // avatar: const Icon(Icons.coffee, color: Colors.brown),
        label: Text('Carbs ${data['carbs'] ?? 0} g'),
      ),
      Chip(
        // avatar: const Icon(Icons.opacity, color: Colors.red),
        label: Text('Fat ${data['fat'] ?? 0} g'),
      ),
      if (diet.isNotEmpty)
        Chip(label: Text(diet)),
      ElevatedButton.icon(
        onPressed: _uid == null
            ? null
            : () async {
                final kcal = (data['calories'] ?? 0).toDouble();
                final protein = (data['protein'] ?? 0).toDouble();
                final carbs = (data['carbs'] ?? 0).toDouble();
                final fat = (data['fat'] ?? 0).toDouble();
                final nameLocal = data['name'] ?? '';
                try {
                  await IntakeService().addConsumption(
                    uid: _uid!,
                    foodId: widget.foodId,
                    foodName: nameLocal,
                    calories: kcal,
                    portions: 1,
                    protein: protein,
                    carbs: carbs,
                    fat: fat,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã ghi nhận: $nameLocal (+${kcal.toString()} kcal)')),
                  );
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Lỗi khi ghi nhận: $e')),
                  );
                }
              },
        icon: const Icon(Icons.restaurant),
        label: const Text('Tôi đã ăn món này'),
        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
      ),
    ],
  ),
),
const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _AuthorTile(authorId: authorId, fallbackName: authorName, fallbackPhotoURL: authorPhoto),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Nguyên liệu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary)),
                    ),
                    const SizedBox(height: 8),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), 
                              child: ExpandableText(
                                text: ingredients.isNotEmpty ? ingredients : 'Chưa có thông tin nguyên liệu',
                                maxLines: 6, // hiển thị 6 dòng, bấm xem thêm để mở rộng
                                style: const TextStyle(fontSize: 16, height: 1.5),
                              ),
                            ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Hướng dẫn nấu',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary),
                      ),
                    ),
                    const SizedBox(height: 8),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _InfoGlassCard(
                        child: ExpandableText(
                          text: _instructions.isNotEmpty ? _instructions : 'Chưa có hướng dẫn.',
                          maxLines: 6,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (_videoController != null && _videoController!.value.isInitialized)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          children: [
                            ClipRRect(borderRadius: BorderRadius.circular(12), child: AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!))),
                            VideoProgressIndicator(_videoController!, allowScrubbing: true),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(icon: const Icon(Icons.replay_10), onPressed: () => _seekBy(const Duration(seconds: -10))),
                                IconButton(icon: Icon(_videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow), onPressed: _togglePlayPause),
                                IconButton(icon: const Icon(Icons.forward_10), onPressed: () => _seekBy(const Duration(seconds: 10))),
                                IconButton(icon: const Icon(Icons.fast_rewind), onPressed: () => _changeSpeed(-0.25)),
                                IconButton(icon: const Icon(Icons.fast_forward), onPressed: () => _changeSpeed(0.25)),
                                Text('${_videoController!.value.playbackSpeed.toStringAsFixed(2)}x'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Bình luận',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primary),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // comment preview + expand
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Preview mode: show up to 4 comments + input. If expanded, show full CommentSection.
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: _commentsExpanded
                                ? CommentSection(foodId: widget.foodId, showList: true)
                                : FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                                    future: FirebaseFirestore.instance
                                        .collection('comments')
                                        .where('foodId', isEqualTo: widget.foodId)
                                        .orderBy('createdAt', descending: true)
                                        .limit(5)
                                        .get(),
                                    builder: (context, snap) {
                                      if (snap.connectionState == ConnectionState.waiting) {
                                        // show a small placeholder + input
                                        return Column(children: [
                                          const SizedBox(height: 8),
                                          CommentSection(foodId: widget.foodId, showList: false),
                                        ]);
                                      }

                                      final docs = snap.data?.docs ?? [];
                                      final count = docs.length;

                                      return Column(
                                        children: [
                                          // show up to 4 preview items
                                          if (count > 0)
                                            ...docs.take(4).map((d) => _previewCommentItem({
                                                  'id': d.id,
                                                  'text': d.data()['text'],
                                                  'authorName': d.data()['authorName'],
                                                  'authorId': d.data()['authorId'],
                                                  'createdAt': d.data()['createdAt'],
                                                })).toList(),
                                          // always show input box (collapsed mode)
                                          const SizedBox(height: 8),
                                          CommentSection(foodId: widget.foodId, showList: false),
                                          const SizedBox(height: 8),
                                          // if more than 4 comments, show expand button
                                          if (count > 4)
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: TextButton(
                                                style: TextButton.styleFrom(
                                                  padding: EdgeInsets.zero,
                                                  minimumSize: const Size(0, 0),
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  foregroundColor: primary,
                                                ),
                                                onPressed: () => setState(() => _commentsExpanded = true),
                                                child: Text('Xem thêm bình luận', style: TextStyle(color: primary)),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Author tile
class _AuthorTile extends StatelessWidget {
  final String authorId;
  final String fallbackName;
  final String fallbackPhotoURL;

  const _AuthorTile({required this.authorId, required this.fallbackName, required this.fallbackPhotoURL});

  @override
  Widget build(BuildContext context) {
    if (authorId.isEmpty) return _buildTile(fallbackName, fallbackPhotoURL);

    final userStream = FirebaseFirestore.instance.collection('users').doc(authorId).snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, snap) {
        final data = snap.data?.data();
        final displayName = (data?['displayName'] ?? '') as String;
        final photo = (data?['photoURL'] ?? '') as String;
        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(userId: authorId),
              ),
            );
          },
          child: _buildTile(displayName.isNotEmpty ? displayName : fallbackName,
                             photo.isNotEmpty ? photo : fallbackPhotoURL),
        );
      },
    );
  }

  Widget _buildTile(String name, String photoUrl) {
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          backgroundColor: const Color.fromRGBO(76, 175, 80, 0.12),
          child: photoUrl.isEmpty ? const Icon(Icons.person, color: Colors.green) : null,
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Người đăng', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ]),
        const Spacer(),
        const Icon(Icons.chevron_right, color: Colors.grey),
      ],
    );
  }
}


/// Glass-style info card
class _InfoGlassCard extends StatelessWidget {
  final Widget child;
  const _InfoGlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(255, 255, 255, 0.92),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color.fromRGBO(0, 0, 0, 0.04), blurRadius: 12,
        offset: const Offset(0, 6))],
      ),
      child: child,
    );
  }
}
/// Reusable widget: rút gọn văn bản dài với nút "Xem thêm" / "Thu gọn"
class ExpandableText extends StatefulWidget {
  final String text;
  final int maxLines;
  final TextStyle? style;
  final String expandLabel;
  final String collapseLabel;

  const ExpandableText({
    super.key,
    required this.text,
    this.maxLines = 6,
    this.style,
    this.expandLabel = 'Xem thêm',
    this.collapseLabel = 'Thu gọn',
  });

  @override
  State<ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<ExpandableText> {
  bool _expanded = false;
  bool _canExpand = false;

  // We detect if text will exceed maxLines by measuring it in a post-frame callback
  @override
  void initState() {
    super.initState();
    // Delay measurement to after first layout
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    final tp = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style ?? DefaultTextStyle.of(context).style),
      maxLines: widget.maxLines,
      textDirection: TextDirection.ltr,
    );
    tp.layout(maxWidth: MediaQuery.of(context).size.width - 32); // approximate padding
    final didOverflow = tp.didExceedMaxLines;
    if (mounted && didOverflow != _canExpand) {
      setState(() => _canExpand = didOverflow);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: ConstrainedBox(
            constraints: _expanded
                ? const BoxConstraints()
                : BoxConstraints(maxHeight: widget.maxLines * (widget.style?.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14) * 1.3),
            child: Text(
              widget.text,
              style: widget.style,
              overflow: TextOverflow.fade,
            ),
          ),
        ),
        if (_canExpand)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(_expanded ? widget.collapseLabel : widget.expandLabel),
            ),
          ),
      ],
    );
  }
}
