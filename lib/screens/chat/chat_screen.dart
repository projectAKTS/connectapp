import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

    final ids = [currentUserId, widget.otherUserId]..sort();
    chatId = ids.join('_');

    // Tell NotificationService we’re in this chat
    CurrentChat.otherUserId = widget.otherUserId;

    // iOS: while this screen is visible, do NOT show foreground banners
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false, // 🔕 disable banner while in-chat
      badge: true,
      sound: true,
    );
  }

  @override
  void dispose() {
    if (CurrentChat.otherUserId == widget.otherUserId) {
      CurrentChat.otherUserId = null;
    }
    // Restore iOS foreground banners when we leave this chat
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, // 🔔 re-enable banners
      badge: true,
      sound: true,
    );
    super.dispose();
  }

  Future<void> _leave() async {
    if (CurrentChat.otherUserId == widget.otherUserId) {
      CurrentChat.otherUserId = null;
    }
    // Also restore banners if user leaves via back button
    FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );
    if (mounted) Navigator.of(context).pop();
  }

  List<types.Message> _messagesFromSnapshots(List<QueryDocumentSnapshot> docs) {
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
            .orderBy('createdAt', descending: true)
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
