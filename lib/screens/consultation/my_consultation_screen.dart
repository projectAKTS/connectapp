// lib/screens/consultation/my_consultations_screen.dart
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import 'package:connect_app/theme/tokens.dart';
import 'package:connect_app/utils/time_utils.dart';

import 'package:connect_app/screens/consultation/consultation_call_screen.dart';
import 'package:connect_app/screens/chat/chat_screen.dart';
import 'package:connect_app/screens/profile/profile_screen.dart';
import 'package:connect_app/services/payment_service.dart';

class MyConsultationsScreen extends StatefulWidget {
  const MyConsultationsScreen({Key? key}) : super(key: key);

  @override
  State<MyConsultationsScreen> createState() => _MyConsultationsScreenState();
}

class _MyConsultationsScreenState extends State<MyConsultationsScreen> {
  // Join is enabled in this window:
  static const Duration _joinEarlyWindow = Duration(minutes: 10);
  static const Duration _joinLateWindow = Duration(minutes: 30);

  // Consider it "Past" once it ended + grace
  static const Duration _pastGrace = Duration(minutes: 5);

  // Rebuild periodically so join button/hints update without refresh
  Timer? _ticker;

  // Collapse/expand Past section
  bool _pastExpanded = false;
  final PaymentService _paymentService = PaymentService();

  final Map<String, Map<String, dynamic>> _userCache = {};
  final Set<String> _userLoading = {};

  @override
  void initState() {
    super.initState();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (currentUid.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .update({'lastConsultationsSeenAt': FieldValue.serverTimestamp()})
          .catchError((_) {});
    }
    _ticker = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _cancelConsultation(String consultationId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel consultation?'),
        content: const Text(
          'Canceling may trigger a refund based on the cancellation policy.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final result = await _paymentService.cancelConsultation(consultationId);
      final refundAmount = (result['refundAmount'] as num?)?.toDouble() ?? 0;
      final refundPercent = (result['refundPercent'] as num?)?.toInt() ?? 0;
      final msg = refundAmount > 0
          ? 'Canceled. Refund: \$${refundAmount.toStringAsFixed(2)} ($refundPercent%).'
          : 'Canceled. No refund (within 1 hour).';
      _snack(msg);
    } catch (e) {
      _snack('Cancel failed: $e');
    }
  }

  void _ensureUserLoaded(String uid) {
    final id = uid.trim();
    if (id.isEmpty || _userCache.containsKey(id) || _userLoading.contains(id)) {
      return;
    }
    _userLoading.add(id);
    FirebaseFirestore.instance.collection('users').doc(id).get().then((snap) {
      if (!mounted) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data != null) _userCache[id] = data;
      _userLoading.remove(id);
      if (mounted) setState(() {});
    }).catchError((_) {
      if (!mounted) return;
      _userLoading.remove(id);
    });
  }

  String _resolveName(Map<String, dynamic>? data, String fallback) {
    final name = (data?['displayName'] ??
            data?['fullName'] ??
            data?['name'] ??
            data?['userName'] ??
            '')
        .toString()
        .trim();
    return name.isNotEmpty ? name : fallback;
  }

  String _resolveAvatar(Map<String, dynamic>? data) {
    final avatar = (data?['avatar'] ??
            data?['photoUrl'] ??
            data?['profilePicture'] ??
            data?['userAvatar'] ??
            '')
        .toString()
        .trim();
    return avatar;
  }

  bool _isJoinEnabled(DateTime now, DateTime? scheduledAt) {
    if (scheduledAt == null) return false;
    final start = scheduledAt.subtract(_joinEarlyWindow);
    final end = scheduledAt.add(_joinLateWindow);
    return now.isAfter(start) && now.isBefore(end);
  }

  String _joinHint(DateTime now, DateTime? scheduledAt) {
    if (scheduledAt == null) return 'Not scheduled';

    final start = scheduledAt.subtract(_joinEarlyWindow);
    final end = scheduledAt.add(_joinLateWindow);

    if (now.isBefore(start)) {
      final mins = start.difference(now).inMinutes;
      if (mins <= 0) return 'Join soon';
      return 'Join available in ${_formatWait(mins)}';
    }
    if (now.isAfter(end)) return 'Expired';
    return 'Ready to join';
  }

  String _formatWait(int mins) {
    if (mins < 60) return '$mins min';
    if (mins < 1440) {
      final h = mins ~/ 60;
      final m = mins % 60;
      return m == 0 ? '${h}h' : '${h}h ${m}m';
    }
    final d = mins ~/ 1440;
    final h = (mins % 1440) ~/ 60;
    return h == 0 ? '${d}d' : '${d}d ${h}h';
  }

  bool _isPast(DateTime now, DateTime scheduledAt, int minutes) {
    final endAt = scheduledAt.add(Duration(minutes: minutes));
    return now.isAfter(endAt.add(_pastGrace));
  }

  String _fmtWhen(DateTime dt) => DateFormat('EEE, MMM d • h:mm a').format(dt);
  String _fmtMoney(num v) => '\$${v.toDouble().toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in to view consultations.')),
      );
    }
    final myUid = currentUser.uid;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('My Consultations'),
        backgroundColor: AppColors.canvas,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('consultations')
            .where('participants', arrayContains: myUid)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Error loading consultations.'));
          }
          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No consultations found.',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }

          final now = DateTime.now();
          final docs = snap.data!.docs;

          final upcoming = <QueryDocumentSnapshot>[];
          final past = <QueryDocumentSnapshot>[];

          for (final d in docs) {
            final data = d.data() as Map<String, dynamic>;
            final scheduledAt = parseFirestoreTimestamp(data['scheduledAt']);
            final status = (data['status'] ?? 'scheduled').toString();
            final isCancelled = status == 'cancelled';

            final minsRaw = (data['minutesRequested'] ?? data['minutes'] ?? 0);
            final mins = (minsRaw is num) ? minsRaw.toInt() : 0;

            if (isCancelled) {
              past.add(d);
            } else if (scheduledAt == null) {
              upcoming.add(d);
            } else if (_isPast(now, scheduledAt, mins)) {
              past.add(d);
            } else {
              upcoming.add(d);
            }
          }

          upcoming.sort((a, b) {
            final aDt = parseFirestoreTimestamp((a.data() as Map)['scheduledAt']) ?? DateTime(9999);
            final bDt = parseFirestoreTimestamp((b.data() as Map)['scheduledAt']) ?? DateTime(9999);
            return aDt.compareTo(bDt);
          });

          past.sort((a, b) {
            final aDt = parseFirestoreTimestamp((a.data() as Map)['scheduledAt']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final bDt = parseFirestoreTimestamp((b.data() as Map)['scheduledAt']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return bDt.compareTo(aDt);
          });

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              // ===== UPCOMING HEADER =====
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        'Upcoming',
                        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      _CountPill(count: upcoming.length),
                      const Spacer(),
                      if (upcoming.isNotEmpty)
                        Text(
                          'Join opens ${_joinEarlyWindow.inMinutes} min early',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 10)),

              // ===== UPCOMING LIST =====
              if (upcoming.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
                    child: Center(
                      child: Text(
                        'No upcoming consultations.',
                        style: TextStyle(color: AppColors.muted, fontSize: 15),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  sliver: SliverList.separated(
                    itemCount: upcoming.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = upcoming[index];
                      final data = doc.data() as Map<String, dynamic>;

                      final consultationId =
                          (data['consultationId'] ?? doc.id).toString();
                      final scheduledAt = parseFirestoreTimestamp(data['scheduledAt']);
                      final canCancel = (data['userId'] ?? '') == myUid;

                      final minsRaw = (data['minutesRequested'] ?? data['minutes'] ?? 0);
                      final minutes = (minsRaw is num) ? minsRaw.toInt() : 0;

                      final costRaw = (data['cost'] ?? 0);
                      final cost = (costRaw is num) ? costRaw : 0;

                      final roomId = (data['roomId'] ?? consultationId).toString();

                      final participants = (data['participants'] ?? const []) as List;
                      final otherUserId = participants.firstWhere(
                        (id) => id != myUid,
                        orElse: () => '',
                      ).toString();

                      final fallbackName = (data['otherUserName'] ??
                              data['partnerName'] ??
                              'Helper')
                          .toString();

                      _ensureUserLoaded(otherUserId);
                      final userData = _userCache[otherUserId];
                      final resolvedName = _resolveName(userData, fallbackName);
                      final avatarUrl = _resolveAvatar(userData);

                      return _ConsultationCard(
                        isPast: false,
                        consultationId: consultationId,
                        scheduledAt: scheduledAt,
                        minutes: minutes,
                        cost: cost,
                        roomId: roomId,
                        otherUserId: otherUserId,
                        displayName: resolvedName,
                        avatarUrl: avatarUrl,
                        joinEnabled: _isJoinEnabled(now, scheduledAt),
                        joinHint: _joinHint(now, scheduledAt),
                        fmtWhen: _fmtWhen,
                        fmtMoney: _fmtMoney,
                        canCancel: canCancel,
                        onOpenProfile: (uid) {
                          if (uid.trim().isEmpty) return;
                          Navigator.of(context).push(
                            CupertinoPageRoute(builder: (_) => ProfileScreen(userID: uid)),
                          );
                        },
                        onMessage: (uid, name, avatar) {
                          if (uid.trim().isEmpty) return;
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (_) => ChatScreen(
                                otherUserId: uid,
                                otherUserName: name,
                                otherUserAvatar: avatar,
                              ),
                            ),
                          );
                        },
                        onJoin: (uid, name) {
                          if (uid.trim().isEmpty) {
                            _snack('No partner found for this consultation.');
                            return;
                          }
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => ConsultationCallScreen(
                                roomId: roomId,
                                otherUserId: uid,
                                otherUserName: name,
                              ),
                            ),
                          );
                        },
                        onCancel: () => _cancelConsultation(consultationId),
                      );
                    },
                  ),
                ),

              // ===== PAST SECTION (COLLAPSIBLE) =====
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: const Border.fromBorderSide(
                        BorderSide(color: AppColors.border),
                      ),
                      boxShadow: const [AppShadows.soft],
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _pastExpanded = !_pastExpanded),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              children: [
                                const Text(
                                  'Past consultations',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.text,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _CountPill(count: past.length),
                                const Spacer(),
                                Icon(
                                  _pastExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: AppColors.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 180),
                          crossFadeState: _pastExpanded
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          firstChild: Column(
                            children: [
                              const Divider(height: 1, color: AppColors.border),
                              if (past.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text(
                                    'No past consultations yet.',
                                    style: TextStyle(color: AppColors.muted),
                                  ),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                                  itemCount: past.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    final doc = past[index];
                                    final data = doc.data() as Map<String, dynamic>;

                                    final consultationId =
                                        (data['consultationId'] ?? doc.id).toString();
                                    final scheduledAt =
                                        parseFirestoreTimestamp(data['scheduledAt']);

                                    final minsRaw =
                                        (data['minutesRequested'] ?? data['minutes'] ?? 0);
                                    final minutes = (minsRaw is num) ? minsRaw.toInt() : 0;

                                    final costRaw = (data['cost'] ?? 0);
                                    final cost = (costRaw is num) ? costRaw : 0;

                                    final roomId =
                                        (data['roomId'] ?? consultationId).toString();

                                    final participants =
                                        (data['participants'] ?? const []) as List;
                                    final otherUserId = participants.firstWhere(
                                      (id) => id != myUid,
                                      orElse: () => '',
                                    ).toString();

                                    final fallbackName = (data['otherUserName'] ??
                                            data['partnerName'] ??
                                            'Helper')
                                        .toString();

                                    _ensureUserLoaded(otherUserId);
                                    final userData = _userCache[otherUserId];
                                    final resolvedName =
                                        _resolveName(userData, fallbackName);
                                    final avatarUrl = _resolveAvatar(userData);

                                    return _ConsultationCard(
                                      isPast: true,
                                      consultationId: consultationId,
                                      scheduledAt: scheduledAt,
                                      minutes: minutes,
                                      cost: cost,
                                      roomId: roomId,
                                      otherUserId: otherUserId,
                                      displayName: resolvedName,
                                      avatarUrl: avatarUrl,
                                      joinEnabled: false,
                                      joinHint: (data['status'] ?? '') == 'cancelled'
                                          ? 'Canceled'
                                          : 'Completed',
                                      fmtWhen: _fmtWhen,
                                      fmtMoney: _fmtMoney,
                                      canCancel: false,
                                      onOpenProfile: (uid) {
                                        if (uid.trim().isEmpty) return;
                                        Navigator.of(context).push(
                                          CupertinoPageRoute(
                                            builder: (_) => ProfileScreen(userID: uid),
                                          ),
                                        );
                                      },
                                      onMessage: (uid, name, avatar) {
                                        if (uid.trim().isEmpty) return;
                                        Navigator.of(context).push(
                                          CupertinoPageRoute(
                                            builder: (_) => ChatScreen(
                                              otherUserId: uid,
                                              otherUserName: name,
                                              otherUserAvatar: avatar,
                                            ),
                                          ),
                                        );
                                      },
                                      onJoin: (_, __) {},
                                      onCancel: () {},
                                    );
                                  },
                                ),
                            ],
                          ),
                          secondChild: const SizedBox(height: 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final int count;
  const _CountPill({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.button,
        borderRadius: BorderRadius.circular(999),
        border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  final bool isPast;

  final String consultationId;
  final DateTime? scheduledAt;
  final int minutes;
  final num cost;
  final String roomId;

  final String otherUserId;
  final String displayName;
  final String avatarUrl;

  final bool joinEnabled;
  final String joinHint;
  final bool canCancel;

  final String Function(DateTime) fmtWhen;
  final String Function(num) fmtMoney;

  final void Function(String uid) onOpenProfile;
  final void Function(String uid, String resolvedName, String avatarUrl) onMessage;
  final void Function(String uid, String resolvedName) onJoin;
  final VoidCallback onCancel;

  const _ConsultationCard({
    required this.isPast,
    required this.consultationId,
    required this.scheduledAt,
    required this.minutes,
    required this.cost,
    required this.roomId,
    required this.otherUserId,
    required this.displayName,
    required this.avatarUrl,
    required this.joinEnabled,
    required this.joinHint,
    required this.canCancel,
    required this.fmtWhen,
    required this.fmtMoney,
    required this.onOpenProfile,
    required this.onMessage,
    required this.onJoin,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final whenText = scheduledAt == null ? 'Not set' : fmtWhen(scheduledAt!);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
        boxShadow: const [AppShadows.soft],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UserPreview(
              uid: otherUserId,
              avatarUrl: avatarUrl,
              onOpenProfile: onOpenProfile,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ConsultationMeta(
                uid: otherUserId,
                displayName: displayName,
                whenText: whenText,
                minutes: minutes,
                costText: fmtMoney(cost),
                hint: joinHint,
                onOpenProfile: onOpenProfile,
              ),
            ),
            const SizedBox(width: 10),
            _ActionsColumn(
              isPast: isPast,
              joinEnabled: joinEnabled,
              uid: otherUserId,
              displayName: displayName,
              avatarUrl: avatarUrl,
              canCancel: canCancel,
              onMessage: onMessage,
              onJoin: onJoin,
              onCancel: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _UserPreview extends StatelessWidget {
  final String uid;
  final String avatarUrl;
  final void Function(String uid) onOpenProfile;

  const _UserPreview({
    required this.uid,
    required this.avatarUrl,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final id = uid.trim();
    final avatarRadius = 24.0;

    if (id.isEmpty) {
      return GestureDetector(
        onTap: () {},
        child: CircleAvatar(
          radius: avatarRadius,
          backgroundColor: AppColors.avatarBg,
          child: const Icon(Icons.person_outline, color: AppColors.avatarFg),
        ),
      );
    }

    return GestureDetector(
      onTap: () => onOpenProfile(id),
      child: CircleAvatar(
        radius: avatarRadius,
        backgroundColor: AppColors.avatarBg,
        backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
        child: avatarUrl.isEmpty
            ? const Icon(Icons.person_outline, color: AppColors.avatarFg)
            : null,
      ),
    );
  }
}

class _ConsultationMeta extends StatelessWidget {
  final String uid;
  final String displayName;

  final String whenText;
  final int minutes;
  final String costText;
  final String hint;

  final void Function(String uid) onOpenProfile;

  const _ConsultationMeta({
    required this.uid,
    required this.displayName,
    required this.whenText,
    required this.minutes,
    required this.costText,
    required this.hint,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    final id = uid.trim();

    final textTheme = Theme.of(context).textTheme;

    Widget nameText(String name) {
      final n = name.trim().isNotEmpty ? name.trim() : displayName;
      return GestureDetector(
        onTap: id.isEmpty ? null : () => onOpenProfile(id),
        child: Text(
          n,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      );
    }

    final nameWidget = nameText(displayName);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        nameWidget,
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.schedule, size: 14, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                whenText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TinyPill(text: '$minutes min'),
            _TinyPill(text: 'Cost: $costText'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          hint,
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActionsColumn extends StatelessWidget {
  final bool isPast;
  final bool joinEnabled;

  final String uid;
  final String displayName;
  final String avatarUrl;
  final bool canCancel;

  final void Function(String uid, String resolvedName, String avatarUrl) onMessage;
  final void Function(String uid, String resolvedName) onJoin;
  final VoidCallback onCancel;

  const _ActionsColumn({
    required this.isPast,
    required this.joinEnabled,
    required this.uid,
    required this.displayName,
    required this.avatarUrl,
    required this.canCancel,
    required this.onMessage,
    required this.onJoin,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final id = uid.trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ Message button (works for both upcoming + past)
        SizedBox(
          height: 40,
          child: OutlinedButton(
            onPressed: id.isEmpty
                ? null
                : () async {
                    onMessage(id, displayName, avatarUrl);
                  },
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.button,
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Icon(Icons.chat_bubble_outline, size: 18),
          ),
        ),

        const SizedBox(height: 10),

        // ✅ Join button (only for upcoming; hidden for past)
        if (!isPast)
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: (!joinEnabled || id.isEmpty)
                  ? null
                  : () async {
                      onJoin(id, displayName);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border.withOpacity(0.6),
                disabledForegroundColor: AppColors.muted,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: const Text('Join'),
            ),
          ),

        if (!isPast && canCancel) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.danger,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
            child: const Text('Cancel'),
          ),
        ],
      ],
    );
  }
}

class _TinyPill extends StatelessWidget {
  final String text;
  const _TinyPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.button,
        borderRadius: BorderRadius.circular(999),
        border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.text,
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
