import 'package:chatty/src/core/services/chat_services.dart';
import 'package:chatty/src/core/services/firebase_option.dart';

import 'package:chatty/src/shared/utils/timestamp.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ChatServices _chatService = ChatServices();
  final TextEditingController _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await _firebaseService.signOut();
      if (context.mounted) {
        context.go('/login');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
          ),
        );
      }
    }
  }

  Future<void> _startnewChat() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    try {
      // check apakah user ada di database
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .get();

      // jika ga ada, munculin snackbar bahwa user not found
      if (userQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }

      // kalau misal emang user ada, kita check lagi apakah chatan kita sama target user nya ada?
      final otherUserId = userQuery.docs.first.id;
      final currentUserId = _firebaseService.currentUser?.uid;

      // kalau ada, kita navigate ke screen chat
      final exsitingQuery = await FirebaseFirestore.instance
          .collection('chats')
          .where('participants', arrayContains: currentUserId)
          .get();

      QueryDocumentSnapshot<Map<String, dynamic>>? existingChat;
      for (final doc in exsitingQuery.docs) {
        final participants = doc['participants'] as List<dynamic>;
        if (participants.contains(otherUserId)) {
          existingChat = doc;
          break;
        }
      }

      if (existingChat != null) {
        if (mounted) {
          context.push('/chats/$otherUserId', extra: email);
        }
        return;
      }

      // kalau ga gada, kita buat chat baru, kemudian navigate ke screen chat
      final chatId = _chatService.generateChatId(currentUserId!, otherUserId);
      await FirebaseFirestore.instance.collection('chats').doc(chatId).set({
        'participants': [currentUserId, otherUserId],
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSender': '',
      });

      if (mounted) {
        Navigator.pop(context);
        context.push('/chats/$otherUserId', extra: email);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to create chat'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showNewChatDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Chat'),
        content: TextField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Enter email address',
            hintText: 'user@example.com',
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _startnewChat();
            },
            child: const Text('Start Chat'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Chatty',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 25,
          ),
        ),
        backgroundColor: Colors.amber[300],
        elevation: 2,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: _chatService.getUserChats(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text('Error!: ${snapshot.error}'),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final chats = snapshot.data?.docs ?? [];

            if (chats.isEmpty) {
              return const _NoMessagesWidget();
            }

            return Container(
              color: Colors.amber[50],
              child: ListView.builder(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                itemCount: chats.length,
                itemBuilder: (context, index) {
                  final chat = chats[index].data() as Map<String, dynamic>;
                  final participants = chat['participants'] as List<dynamic>;
                  final otherUserId = participants
                      .firstWhere((id) => id != _chatService.currentUser?.uid);
                  return FutureBuilder(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(otherUserId)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const ListTile(
                            title: Text('Loading...'),
                          );
                        }

                        final userData =
                            userSnapshot.data?.data() as Map<String, dynamic>?;
                        print('ID!!: ${userData?['uid']}');
                        print('Namaaaa: ${userData?['displayName']}');
                        final otherUserName = userData?['displayName'] ?? 'Unknown';

                        return _ChatListItem(
                          name: otherUserName,
                          lastMessage: chat['lastMessage'] ?? 'No Message Yet',
                          time: formatTimeStamp(chat['lastMessageTime']),
                          unreadCount: 0,
                          onTap: () => context.push('/chats/$otherUserId',
                              extra: otherUserName),
                        );
                      });
                },
              ),
            );
          }),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        backgroundColor: Colors.amber[400],
        foregroundColor: Colors.black87,
        child: const Icon(Icons.chat),
      ),
    );
  }

}

class _ChatListItem extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final VoidCallback onTap;

  const _ChatListItem({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.amber[300],
          foregroundColor: Colors.black87,
          child: Text(
            name[0],
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          lastMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: TextStyle(
                color: Colors.amber[700],
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.amber[600],
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoMessagesWidget extends StatelessWidget {
  const _NoMessagesWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.amber[50],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64.r,
              color: Colors.amber[300],
            ),
            SizedBox(height: 16.h),
            Text(
              'No chats yet',
              style: TextStyle(
                fontSize: 18.sp,
                color: Colors.amber[800],
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Start a new conversation!',
              style: TextStyle(
                fontSize: 14.sp,
                color: Colors.amber[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}