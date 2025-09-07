import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reface/services/auth_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _uid = AuthService().uid;

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _db.collection('users').doc(uid);

  CollectionReference<Map<String, dynamic>> _sessionsCol(String uid) =>
      _userDoc(uid).collection('sessions');

  /// 최초 입장 시 유저 문서 보장
  Future<void> ensureUserDoc() async {
    if (_uid.isEmpty) {
      throw StateError('No signed-in user');
    }
    final ref = _userDoc(_uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await ref.update({'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  /// 예시 세션 추가 (점수 기록 등)
  Future<void> addSampleSession({required int score}) async {
    if (_uid.isEmpty) {
      throw StateError('No signed-in user');
    }
    await _sessionsCol(_uid).add({
      'score': score,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// 현재 사용자 세션 스트림
  Stream<QuerySnapshot<Map<String, dynamic>>> sessionsStream() async* {
    if (_uid.isEmpty) {
      // 로그인 전엔 빈 스트림 반환
      yield* Stream<QuerySnapshot<Map<String, dynamic>>>.fromIterable([]);
      return;
    }
    yield* _sessionsCol(_uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// 모든 사용자 데이터 삭제(세션 전부 + user doc)
  Future<void> deleteAllUserData(String uid) async {
    final userRef = _userDoc(uid);
    final sessions = await _sessionsCol(uid).get();

    // 큰 컬렉션이면 나눠서 배치 커밋하세요.
    final batch = _db.batch();
    for (final d in sessions.docs) {
      batch.delete(d.reference);
    }
    batch.delete(userRef);
    await batch.commit();
  }
}
