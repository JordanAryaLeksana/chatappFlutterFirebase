import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;

  // function getMessages (untuk dapetin data chat dari firebase)
  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // function sendMessage (untuk ngirim message ke firebase)
  Future<void> sendMessage(String chatId, String message) async {
    final user = currentUser;
    if (user == null) throw 'user not authenticated';

    // check apakah chat ada, kalau ngga, buat chat baru
    final chatDoc = await _firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) {
      final participants = chatId.split('_');
      await _firestore.collection('chats').doc(chatId).set(
        {
          'participants': participants,
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSender': '',
        },
      );
    }

    final messageData = {
      'senderId': user.uid,
      'senderName': user.displayName ?? 'Hengker',
      'message': message,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': message,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSender': user.uid,
    });
  }

  // function getUserChats (untuk dapetin list chat yang sudah ada)
  Stream<QuerySnapshot> getUserChats() {
    final user = currentUser;
    if (user == null) throw 'user not authenticated';

    return _firestore
        .collection('chats')
        .where('participants', arrayContains: user.uid)
        .orderBy('lastMessageTime', descending: true)
        .snapshots();
  }

  // generate a consistent chat id
  String generateChatId(String usreId1, String userId2) {
    final ids = [usreId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  // delete message
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').doc(messageId).delete();
  }

}
