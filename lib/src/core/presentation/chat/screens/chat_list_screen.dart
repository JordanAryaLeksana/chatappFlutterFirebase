import 'package:chatty/src/core/services/chat_services.dart';
import 'package:chatty/src/core/services/firebase_option.dart';
import 'package:chatty/src/shared/extensions/dynamic.dart';
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
  final TextEditingController _emailController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  final ChatServices _chatService = ChatServices();
  final List<Map<String, dynamic>> _mockChats = [
    {
      'id': '1',
      'name': 'John Doe',
      'lastMessage': 'Hey, how are you?',
      'time': '09:30',
      'unreadCount': 2,
    },
    {
      'id': '2',
      'name': 'Jane Smith',
      'lastMessage': 'See you tomorrow!',
      'time': '08:45',
      'unreadCount': 0,
    },
    {
      'id': '3',
      'name': 'Mike Johnson',
      'lastMessage': 'Thanks for your help',
      'time': 'Yesterday',
      'unreadCount': 1,
    },
  ];

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _signOut(BuildContext context) async {
    try {
      await _firebaseService.signOut();
      if (context.mounted) {
        context.go('/login');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sign out failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
              final email = _emailController.text.trim();
              if (email.isEmpty) return;
              try {
                final userQuery = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: email)
                    .where('provider', isEqualTo: 'google')
                    .get();
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

                final otherUserid = userQuery.docs.first.id;
                final currentUserId = _firebaseService.currentUser?.uid;

                final exitingQuery = await FirebaseFirestore.instance
                    .collection('chats')
                    .where('participants', arrayContains: currentUserId)
                    .get();

                QueryDocumentSnapshot<Map<String, dynamic>>? existingChat;
                for (final doc in exitingQuery.docs) {
                  final participants = doc['participants'] as List<dynamic>;
                  if (participants.contains(otherUserid)) {
                    existingChat = doc;
                    break;
                  }
                }

                if (existingChat != null) {
                  if (mounted) {
                    context.push('/chats/${otherUserid}', extra: email);
                  }
                  return;
                }

                final chatId =
                    _chatService.generateChatId(currentUserId!, otherUserid);
                await FirebaseFirestore.instance
                    .collection('chats')
                    .doc(chatId)
                    .set({
                  'participants': [currentUserId, otherUserid],
                  'lastMessageSender': '',
                  'lastMessage': '',
                  'createdAt': FieldValue.serverTimestamp(),
                  'lastMessageTime': FieldValue.serverTimestamp(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  context.push('/chats/$otherUserid', extra: email);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }
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
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: _mockChats.isEmpty
          ? const _NoMessagesWidget()
          : StreamBuilder<QuerySnapshot>(
              stream: _chatService.getUserChats(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Colors.red, fontSize: 16.sp),
                    ),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.w,
                      color: Colors.blue,
                    ),
                  );
                }
                final chats = snapshot.data?.docs ?? [];
                if (chats.isEmpty) {
                  return const _NoMessagesWidget();
                }
                return ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index].data() as Map<String, dynamic>;
                    final participants = chat['participants'] as List<dynamic>;
                    final otherUserId = participants.firstWhere(
                        (element) => element != _chatService.currentUser?.uid);
                    return FutureBuilder(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .doc(otherUserId)
                            .get(),
                        builder: (context, userSnapShot) {
                          if (!userSnapShot.hasData) {
                            return const ListTile(
                              title: Text('Loading...'),
                            );
                          }

                          final userData = userSnapShot.data!.data();
                          final otherUserName = userData?['name'] ?? 'Unknown User';

                          return _ChatListItem(
                            name: otherUserName, 
                            lastMessage: chat['lastMessage'].isNullOrEmpty() 
                                ? 'No messages yet'
                                : chat['lastMessage'],
                            time: _formatTime(chat['lastMessageTime'] as Timestamp? ?? Timestamp.now()),
                            unreadCount: chat['unreadCount'],
                            onTap: () => context.push('/chats/${chat['id']}', extra: chat['name']));
                        });
                  },
                );
              }),
      floatingActionButton: FloatingActionButton(
        onPressed: _showNewChatDialog,
        child: const Icon(Icons.chat),
      ),
    );
  }

  String _formatTime(Timestamp timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(name[0]),
      ),
      title: Text(name),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            time,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12.sp,
            ),
          ),
          if (unreadCount > 0) ...[
            const SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                unreadCount.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoMessagesWidget extends StatelessWidget {
  const _NoMessagesWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64.r,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16.h),
          Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 18.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Start a new conversation!',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}
