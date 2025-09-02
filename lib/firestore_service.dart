import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 현재 로그인한 사용자 uid
  String get _uid {
    final u = _auth.currentUser;
    if (u == null) {
      throw StateError('No authenticated user. FirebaseAuth.currentUser is null.');
    }
    return u.uid;
  }

  // ==== 경로 Helper ====
  DocumentReference<Map<String, dynamic>> _userDoc([String? uid]) =>
      _db.collection('users').doc(uid ?? _uid);

  CollectionReference<Map<String, dynamic>> _sessionsCol([String? uid]) =>
      _userDoc(uid).collection('trainingSessions');

  DocumentReference<Map<String, dynamic>> _sessionDoc(String sid, [String? uid]) =>
      _sessionsCol(uid).doc(sid);

  CollectionReference<Map<String, dynamic>> _setsCol(String sid, [String? uid]) =>
      _sessionDoc(sid, uid).collection('sets');

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> sessionsStream() {
    return _sessionsCol()
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((qs) => qs.docs);
  }

  Future<String> startSession({
    required String expr,
    Map<String, dynamic>? extra, // 필요시 확장 필드
  }) async {
    final ref = _sessionsCol().doc(); // sid 자동 생성
    final data = <String, dynamic>{
      'expr': expr,
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
      if (extra != null) ...extra,
    };
    await ref.set(data);
    return ref.id;
  }

  // =========================
  // 특정 세션 1건 조회
  // =========================
  Future<DocumentSnapshot<Map<String, dynamic>>> getSession(String sid) {
    return _sessionDoc(sid).get();
  }

  // =========================
  // 특정 세션의 세트 목록 스트림
  // BEFORE: collection('training_sessions').doc(sid).collection('sets')
  // AFTER : users/{uid}/trainingSessions/{sid}/sets
  // =========================
  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> setsStream(String sid) {
    return _setsCol(sid)
        .orderBy('createdAt')
        .snapshots()
        .map((qs) => qs.docs);
  }

  // =========================
  // 세트 저장 (점수/대칭/캡처)
  // capture: { landmarkId: {x,y,z?,visibility?}, ... }
  // score  : 0~100
  // symmetry: { absDiff, ratio }
  // =========================
  Future<String> saveSet({
    required String sid,
    required Map<String, dynamic> capture,
    required double score,
    required Map<String, dynamic> symmetry,
    Map<String, dynamic>? extra,
  }) async {
    final ref = _setsCol(sid).doc();
    final data = <String, dynamic>{
      'capture': capture,
      'score': score,
      'symmetry': symmetry,
      'createdAt': FieldValue.serverTimestamp(),
      if (extra != null) ...extra,
    };
    await ref.set(data);
    return ref.id;
  }

  // =========================
  // 세션 완료(최종 점수/요약 저장)
  // =========================
  Future<void> finalizeSession({
    required String sid,
    required double finalScore,
    Map<String, dynamic>? summary, // 선택
    Map<String, dynamic>? extra,
  }) async {
    await _sessionDoc(sid).set({
      'finalScore': finalScore,
      'summary': summary ?? FieldValue.delete(),
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      if (extra != null) ...extra,
    }, SetOptions(merge: true));
  }

  // =========================
  // 세션 삭제 (선택)
  // 세트 하위 컬렉션까지 함께 삭제하려면 배치/트랜잭션 또는 Cloud Function 사용 권장
  // =========================
  Future<void> deleteSession(String sid) async {
    // 하위 sets 문서 삭제
    final sets = await _setsCol(sid).get();
    final batch = _db.batch();
    for (final d in sets.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_sessionDoc(sid));
    await batch.commit();
  }

  // =========================
  // 통계용 헬퍼(예시): 최근 N개의 세션 요약 불러오기
  // =========================
  Future<List<Map<String, dynamic>>> recentSessions({int limit = 20}) async {
    final qs = await _sessionsCol()
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .get();
    return qs.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }
}
