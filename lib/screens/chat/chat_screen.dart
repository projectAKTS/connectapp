import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

import '../../services/current_chat.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;

  const ChatScreen({required this.otherUserId, Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final String currentUserId;
  late final String chatId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser!.uid;

    // Deterministic chat id: uidA_uidB (alphabetical)
    final ids = [currentUserId, widget.otherUserId]..sort();
    chatId = ids.join('_');

    // Suppress push banners for this peer while this screen is visible
    CurrentChat.otherUserId = widget.otherUserId;
  }

  @override
  void dispose() {
    // Re-enable chat banners when leaving this screen
    if (CurrentChat.otherUserId == widget.otherUserId) {
      CurrentChat.otherUserId = null;
    }
    super.dispose();
  }

  Future<void> _leave() async {
    // Clear and pop
    if (CurrentChat.otherUserId == widget.otherUserId) {
      CurrentChat.otherUserId = null;
    }
    if (mounted) Navigator.of(context).pop();
  }

  List<types.Message> _messagesFromSnapshots(List<QueryDocumentSnapshot> docs) {
    // Mapping Firestore -> flutter_chat_types (keep newest-first order from the query)
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return types.TextMessage(
        id: doc.id,
        author: types.User(id: data['authorId'] as String),
        createdAt: (data['createdAt'] as Timestamp).millisecondsSinceEpoch,
        text: data['text'] as String,
      );
    }).toList();
  }

  Future<void> _handleSendPressed(types.PartialText message) async {
    final msgRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(const Uuid().v4());

    await msgRef.set({
      'authorId': currentUserId,
      'createdAt': Timestamp.now(),
      'text': message.text,
    });

    // (Optional) write lightweight chat doc for listing/lastMessage, etc.
    // await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
    //   'participants': [currentUserId, widget.otherUserId],
    //   'lastMessage': message.text,
    //   'lastMessageAt': FieldValue.serverTimestamp(),
    // }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _leave,
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('createdAt', descending: true) // newest first
            .snapshots(),
        builder: (context, snapshot) {
          final messages = snapshot.hasData
              ? _messagesFromSnapshots(snapshot.data!.docs)
              : const <types.Message>[];

          return Chat(
            messages: messages,
            onSendPressed: _handleSendPressed,
            user: types.User(id: currentUserId),
            showUserAvatars: true,
            showUserNames: true,
            // Keeps keyboard from covering the composer on iOS
            useTopSafeAreaInset: false,
            disableImageGallery: true,
            theme: const DefaultChatTheme(
              primaryColor: Color(0xFF7367F0),
              sentMessageBodyTextStyle: TextStyle(
                color: Colors.white,
                decoration: TextDecoration.none,
              ),
              receivedMessageBodyTextStyle: TextStyle(
                color: Colors.black87,
                decoration: TextDecoration.none,
              ),
            ),
          );
        },
      ),
    );
  }
}
