import 'package:flutter/material.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends StatefulWidget {
  final String otherUserId;

  const ChatScreen({required this.otherUserId, Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late String currentUserId;
  late String chatId;

  @override
  void initState() {
    super.initState();
    currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final sortedIds = [currentUserId, widget.otherUserId]..sort();
    chatId = sortedIds.join('_');
  }

  List<types.Message> _messagesFromSnapshots(List<QueryDocumentSnapshot> docs) {
    // DO NOT REVERSE!
    return docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return types.TextMessage(
        id: doc.id,
        author: types.User(id: data['authorId']),
        createdAt: (data['createdAt'] as Timestamp).millisecondsSinceEpoch,
        text: data['text'],
      );
    }).toList();
  }

  void _handleSendPressed(types.PartialText message) async {
    final doc = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(const Uuid().v4());

    await doc.set({
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
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .orderBy('createdAt', descending: true) // NEWEST FIRST
            .snapshots(),
        builder: (context, snapshot) {
          final messages = snapshot.hasData
              ? _messagesFromSnapshots(snapshot.data!.docs)
              : <types.Message>[];

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
