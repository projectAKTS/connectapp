import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/screens/consultation/consultation_booking_screen.dart';
import 'package:connect_app/screens/posts/post_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String mode; // 'default' or 'consultation'
  const SearchScreen({Key? key, this.mode = 'default'}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = false;

  List<Map<String, dynamic>> userResults = [];
  List<Map<String, dynamic>> postResults = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String rawQuery) async {
    FocusScope.of(context).unfocus();
    final query = rawQuery.trim();
    setState(() {
      userResults.clear();
      postResults.clear();
      isLoading = true;
    });

    if (query.isEmpty) {
      setState(() => isLoading = false);
      return;
    }

    try {
      // --- USERS ---
      final users = <Map<String, dynamic>>[];
      final userRef = FirebaseFirestore.instance.collection('users');

      Future<void> addUsers(QuerySnapshot snap) async {
        for (final d in snap.docs) {
          final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
          m['id'] = d.id;
          if (!users.any((u) => u['id'] == m['id'])) users.add(m);
        }
      }

      Future<QuerySnapshot> byField(String field) {
        return userRef
            .where(field, isGreaterThanOrEqualTo: query)
            .where(field, isLessThanOrEqualTo: '$query\uf8ff')
            .get();
      }

      final nameSnap = await byField('fullName');
      final bioSnap = await byField('bio');
      final journeySnap = await byField('journey');
      await addUsers(nameSnap);
      await addUsers(bioSnap);
      await addUsers(journeySnap);

      if (widget.mode == 'consultation') {
        users.retainWhere((u) => u['isHelper'] == true);
      }

      // --- POSTS (only in default mode) ---
      final posts = <Map<String, dynamic>>[];
      if (widget.mode == 'default') {
        final contentSnap = await FirebaseFirestore.instance
            .collection('posts')
            .where('content', isGreaterThanOrEqualTo: query)
            .where('content', isLessThanOrEqualTo: '$query\uf8ff')
            .get();
        for (final d in contentSnap.docs) {
          final m =
              Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
          m['id'] = d.id;
          posts.add(m);
        }
      }

      if (!mounted) return;
      setState(() {
        postResults = posts;
        userResults = users;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        postResults.clear();
        userResults.clear();
        isLoading = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Search failed: $e')));
    }
  }

  Widget _pillSearchField() {
    return TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: _search,
      decoration: InputDecoration(
        hintText: widget.mode == 'consultation'
            ? 'Search consultants…'
            : 'Search users or posts…',
        filled: true,
        fillColor: AppColors.button,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search, color: AppColors.muted),
          onPressed: () => _search(_searchController.text),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    );
  }

  Widget _softCard({required Widget child}) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.border.withOpacity(0.65), width: 1),
          boxShadow: const [AppShadows.soft],
        ),
        child: child,
      );

  Widget _userTile(Map<String, dynamic> u) {
    return _softCard(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: _avatar(url: u['photoUrl'] as String?),
        title: Text(
          (u['fullName'] ?? 'Unknown') as String,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        subtitle: (u['bio'] != null && (u['bio'] as String).isNotEmpty)
            ? Text(
                u['bio'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted),
              )
            : null,
        onTap: () {
          final id = (u['id'] as String?) ?? '';
          if (id.isEmpty) return;
          if (widget.mode == 'consultation') {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => ConsultationBookingScreen(
                  targetUserId: id,
                  targetUserName: (u['fullName'] ?? 'Helper') as String,
                ),
              ),
            );
          } else {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(userID: id)),
            );
          }
        },
      ),
    );
  }

  Widget _postTile(Map<String, dynamic> p) {
    final userName = (p['userName'] ?? 'Anonymous') as String;
    return _softCard(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: CircleAvatar(
          backgroundColor: AppColors.avatarBg,
          child: Text(
            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
            style: const TextStyle(
                color: AppColors.text, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(
          userName,
          style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppColors.text),
        ),
        subtitle: Text(
          (p['content'] ?? '') as String,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.text),
        ),
        onTap: () {
          final id = (p['id'] as String?) ?? '';
          if (id.isEmpty) return;
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(builder: (_) => PostDetailScreen(postId: id)),
          );
        },
      ),
    );
  }

  Widget _avatar({String? url}) {
    if (url == null || url.isEmpty) {
      return const CircleAvatar(
        backgroundColor: AppColors.avatarBg,
        child: Icon(Icons.person_outline, color: AppColors.avatarFg),
      );
    }
    return CircleAvatar(backgroundImage: NetworkImage(url));
  }

  Widget _placeholder() {
    final title = widget.mode == 'consultation'
        ? 'Find a consultant'
        : 'Suggested categories';
    final subtitle = widget.mode == 'consultation'
        ? 'Try searching for helpers offering audio or video calls.'
        : 'Try searching for “Study Permit”, “Housing”, or “Talk to a Refugee”.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            widget.mode == 'consultation' ? 'Choose a consultant' : 'Search',
            style: const TextStyle(color: AppColors.text),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _pillSearchField(),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : (query.isEmpty)
                      ? _placeholder()
                      : (userResults.isEmpty && postResults.isEmpty)
                          ? const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 32, vertical: 24),
                              child: Text(
                                'No results. Try another keyword.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.muted),
                              ),
                            )
                          : ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              children: <Widget>[
                                if (userResults.isNotEmpty)
                                  Text(
                                    widget.mode == 'consultation'
                                        ? 'Consultants'
                                        : 'Users',
                                    style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text),
                                  ),
                                const SizedBox(height: 8),
                                ...userResults
                                    .map((u) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 12),
                                          child: _userTile(u),
                                        ))
                                    .toList(),
                                if (widget.mode == 'default' &&
                                    postResults.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Posts',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.text),
                                  ),
                                  const SizedBox(height: 8),
                                  ...postResults
                                      .map((p) => Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: _postTile(p),
                                          ))
                                      .toList(),
                                ],
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
