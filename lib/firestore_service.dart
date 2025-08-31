// lib/firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  /// users/{uid} 문서가 없으면 생성
  Future<void> ensureUserDoc({String? uid, Map<String, dynamic>? defaults}) async {
    final id = uid ?? _uid;
    if (id == null) return;

    final userRef = _db.collection('users').doc(id);
    final snap = await userRef.get();
    if (!snap.exists) {
      await userRef.set({
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'email': _auth.currentUser?.email,
        ...?defaults,
      });
    } else {
      await userRef.update({'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  /// 홈 테스트용 샘플 세션 추가
  Future<DocumentReference<Map<String, dynamic>>> addSampleSession({
    required int score,
  }) {
    final data = <String, dynamic>{
      'uid': _uid,
      'score': score,
      'createdAt': FieldValue.serverTimestamp(),
    };
    return _db.collection('training_sessions').add(data);
  }

  /// 임의 세션 추가(옵션)
  Future<DocumentReference<Map<String, dynamic>>> addSession(
    Map<String, dynamic> data,
  ) {
    data['uid'] ??= _uid;
    data['createdAt'] ??= FieldValue.serverTimestamp();
    return _db.collection('training_sessions').add(
          Map<String, dynamic>.from(data),
        );
  }

  /// 최신 세션 스트림(옵션)
  Stream<QuerySnapshot<Map<String, dynamic>>> sessionsStream({int limit = 50}) {
    Query<Map<String, dynamic>> q = _db
        .collection('training_sessions')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    final uid = _uid;
    if (uid != null) q = q.where('uid', isEqualTo: uid);
    return q.snapshots();
  }

  /// 사용자 데이터 전체 삭제
  Future<void> deleteAllUserData(String uid) async {
    await _deleteByQuery(
      _db.collection('training_sessions').where('uid', isEqualTo: uid),
    );

    final userRef = _db.collection('users').doc(uid);
    await _deleteCollection(userRef.collection('sessions'));
    await _deleteCollection(userRef.collection('records'));

    try {
      await userRef.delete();
    } catch (_) {}
  }

  Future<void> _deleteByQuery(
    Query<Map<String, dynamic>> query, {
    int batchSize = 250,
  }) async {
    while (true) {
      final snap = await query.limit(batchSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) break;
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> col, {
    int batchSize = 250,
  }) async {
    while (true) {
      final snap = await col.limit(batchSize).get();
      if (snap.docs.isEmpty) break;

      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < batchSize) break;
    }
  }
}