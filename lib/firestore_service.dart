import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

    Future<void> ensureUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인 필요');
    await user.reload();
    if (!(user.emailVerified)) {
      // 미인증이면 아무 것도 만들지 않음
      return;
    }
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  /// 예시 저장(밑 단락까지 예시임)
  Future<void> addSampleSession({required int score}) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _db.collection('users').doc(uid).collection('sessions').add({
      'score': score,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sessionsStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _db.collection('users')
      .doc(uid)
      .collection('sessions')
      .orderBy('createdAt', descending: true)
      .snapshots();
  }

  /// 회원탈퇴 전 사용자 데이터 삭제->문서 수 많아질 경우 fuction으로 만들어야 될듯 윤서야
  Future<void> deleteAllUserData(String uid) async {
    // 1) subcollection(sessions) 문서들 삭제(store 내용을 삭제)
    final sessionsRef = _db.collection('users').doc(uid).collection('sessions');
    final sessions = await sessionsRef.get();
    final batch = _db.batch();
    for (final d in sessions.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();

    // 2) users/{uid} 문서 삭제(store 자체를 삭제)
    await _db.collection('users').doc(uid).delete();
  }
}