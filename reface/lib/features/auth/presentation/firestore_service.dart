import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  /// 사용자 문서 생성 (최초 로그인 시에만)
  Future<void> ensureUserDoc() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인 필요');
    await user.reload();
    if (!(user.emailVerified)) {
      // 미인증이면 x
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
    /// 테스트
    Future<void> addSampleSession({required int score}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('로그인 필요');

    final userRef = _db.collection('users').doc(user.uid);

    final userSnap = await userRef.get();
    if (!userSnap.exists) {
        await ensureUserDoc(); // 이미 정의된 메서드 활용
    }

    await userRef.collection('sessions').add({
        'score': score,
        'createdAt': FieldValue.serverTimestamp(),
    });

    // 최신화 시간도 갱신
    await userRef.update({'updatedAt': FieldValue.serverTimestamp()});
    }
  /// 세션 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> sessionsStream() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _db
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// 회원탈퇴 전 사용자 데이터 전체 삭제
  Future<void> deleteAllUserData(String uid) async {
    final userDoc = _db.collection('users').doc(uid);

    // 서브(다른 서브 생기면 추가해야됨)
    await _deleteCollection(userDoc.collection('sessions'));
    await _deleteCollection(userDoc.collection('expressions'));
    
    await userDoc.delete();
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> colRef, {
    int batchSize = 300,
  }) async {
    while (true) {
      final snap = await colRef.limit(batchSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      await Future.delayed(const Duration(milliseconds: 50));
    }
  }
}