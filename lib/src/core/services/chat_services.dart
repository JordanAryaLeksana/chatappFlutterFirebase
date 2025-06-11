import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  //functn get message
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  //func send message
  void sendMessage(String chatId, String message) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) {
      final participant = chatId.split('_');
      await _firestore.collection('chats').doc(chatId).set({
        'participants': [user.uid, participant],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });
    }

    final messageData = {
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Unknown',
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    await _firestore.collection('chats').doc(chatId).update(
      {
        'lastMessage': message,
        'lastMessageSender': user.uid,
        'lastMessageTime': FieldValue.serverTimestamp(),
      },
    );
  }
  //function get User Chats

  Stream<QuerySnapshot> getUserChats() {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  //generate consistent chat ID

  String generateChatId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }
}
