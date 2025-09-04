import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connect_app/theme/tokens.dart';

class SelectConsultantScreen extends StatefulWidget {
  const SelectConsultantScreen({Key? key}) : super(key: key);

  @override
  State<SelectConsultantScreen> createState() => _SelectConsultantScreenState();
}

class _SelectConsultantScreenState extends State<SelectConsultantScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _runSearch([String? raw]) async {
    final q = (raw ?? _controller.text).trim();
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _results = [];
    });

    try {
      // Case-insensitive search: if you maintain a `fullNameLower` field,
      // this will give the best results. Otherwise we fall back to `fullName`.
      final String qLower = q.toLowerCase();

      // Try by lowercased field first (recommended schema)
      QuerySnapshot snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('users')
            .where('fullNameLower', isGreaterThanOrEqualTo: qLower)
            .where('fullNameLower', isLessThanOrEqualTo: '$qLower\uf8ff')
            .get();
      } catch (_) {
        // Fallback if you don't have `fullNameLower`
        snap = await FirebaseFirestore.instance
            .collection('users')
            .where('fullName', isGreaterThanOrEqualTo: q)
            .where('fullName', isLessThanOrEqualTo: '$q\uf8ff')
            .get();
      }

      final items = <Map<String, dynamic>>[];
      for (final d in snap.docs) {
        final m = Map<String, dynamic>.from(d.data() as Map<String, dynamic>);
        m['id'] = d.id;
        items.add(m);
      }

      // Optional client-side filter: only consultants if the flag exists
      // (won't throw if the field is missing).
      final filtered = items.where((m) {
        if (!m.containsKey('isConsultant')) return true; // no flag -> show all
        final v = m['isConsultant'];
        return v is bool ? v : true;
      }).toList();

      setState(() {
        _results = filtered;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _results = [];
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Search failed: $e')),
      );
    }
  }

  void _openBooking(Map<String, dynamic> u) {
    final userId = (u['id'] ?? '') as String;
    final name = (u['fullName'] ?? 'Unknown') as String;
    final rate = (u['ratePerMinute'] as num?)?.toInt();

    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing user info')),
      );
      return;
    }

    Navigator.of(context).pushNamed(
      '/consultation',
      arguments: {
        'targetUserId': userId,
        'targetUserName': name,
        'ratePerMinute': rate,
      },
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: _runSearch,
      decoration: InputDecoration(
        hintText: 'Search consultants…',
        filled: true,
        // ✅ Match all other buttons/pills in the app
        fillColor: AppColors.button,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        suffixIcon: IconButton(
          icon: const Icon(Icons.search, color: AppColors.muted),
          onPressed: () => _runSearch(),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide.none,
          borderRadius: BorderRadius.circular(28),
        ),
      ),
    );
  }

  Widget _avatar(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) {
      return const CircleAvatar(
        backgroundColor: AppColors.avatarBg,
        child: Icon(Icons.person_outline, color: AppColors.avatarFg),
      );
    }
    return CircleAvatar(backgroundImage: NetworkImage(photoUrl));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        appBar: AppBar(
          backgroundColor: AppColors.canvas,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: const Text('Choose a consultant',
              style: TextStyle(color: AppColors.text)),
          iconTheme: const IconThemeData(color: AppColors.text),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _searchField(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _results.isEmpty
                      ? const Center(
                          child: Text('No helpers found',
                              style: TextStyle(color: AppColors.muted)),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemBuilder: (_, i) {
                            final u = _results[i];
                            final name =
                                (u['fullName'] ?? 'Unknown') as String;
                            final bio = (u['bio'] ?? '') as String;
                            final photo = (u['photoUrl'] ?? '') as String;
                            final rate = (u['ratePerMinute'] as num?)?.toInt();

                            return Container(
                              decoration: BoxDecoration(
                                color: AppColors.card,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xl),
                                border: Border.all(
                                  color:
                                      AppColors.border.withOpacity(0.65),
                                  width: 1,
                                ),
                                boxShadow: const [AppShadows.soft],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                leading: _avatar(photo),
                                title: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (bio.isNotEmpty)
                                      Text(
                                        bio,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: AppColors.muted),
                                      ),
                                    if (rate != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          '\$${rate}/min',
                                          style: const TextStyle(
                                            color: AppColors.text,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right,
                                    color: AppColors.muted),
                                onTap: () => _openBooking(u),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemCount: _results.length,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
