import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Future<void> ensureUserDoc() async {
    final ref = _db.collection('users').doc(_uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'createdAt': FieldValue.serverTimestamp(),
        'email': FirebaseAuth.instance.currentUser?.email,
      }, SetOptions(merge: true));
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> sessionsStream() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('sessions')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> addSampleSession({required int score}) async {
    await _db
        .collection('users')
        .doc(_uid)
        .collection('sessions')
        .add({
      'score': score,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAllUserData(String uid) async {
    await _deleteAllFirestore(uid);
    await _deleteAllStorage(uid);
  }

  Future<void> _deleteAllFirestore(String uid) async {
    final userRef = _db.collection('users').doc(uid);

    // 1) 서브컬렉션(sessions 등) 안전 삭제
    Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> col) async {
      const int batchSize = 300;
      Query<Map<String, dynamic>> query = col.limit(batchSize);

      while (true) {
        final snap = await query.get();
        if (snap.docs.isEmpty) break;

        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < batchSize) break;
      }
    }

    try {
      final sessionsCol = userRef.collection('sessions');
      await _deleteCollection(sessionsCol);
    } catch (_) {
      // 컬렉션이 없거나 권한 문제 시에도 탈퇴는 계속 진행
    }

    // 2) 최상위 user 문서 삭제
    try {
      await userRef.delete();
    } on FirebaseException catch (e) {
      if (e.code != 'not-found' && e.code != 'permission-denied') {
        rethrow;
      }
    } catch (_) {/* 무시 */}
  }

  Future<void> _deleteAllStorage(String uid) async {
    final base = _storage.ref().child('users/$uid');

    Future<void> _deleteFolder(Reference folder) async {
      try {
        final listing = await folder.listAll();
        for (final item in listing.items) {
          try {
            await item.delete();
          } catch (_) {/* 개별 파일 삭제 실패 무시 */}
        }
        for (final prefix in listing.prefixes) {
          await _deleteFolder(prefix);
        }
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') {
          // ignore others
        }
      } catch (_) {/* 무시 */}
    }

    await _deleteFolder(base);
  }

  // ====== ⬇️ 추가: 초기 표정 저장/조회/스트림 ======

  /// 초기 표정 노트 저장 (users/{uid}/meta/initial_expressions)
  Future<void> setInitialExpressions({
    required Map<String, String> notes,
  }) async {
    await ensureUserDoc();
    final ref = _db
        .collection('users')
        .doc(_uid)
        .collection('meta')
        .doc('initial_expressions');

    await ref.set({
      'notes': notes,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 초기 표정 노트 단건 조회
  Future<Map<String, String>> getInitialExpressions() async {
    final doc = await _db
        .collection('users')
        .doc(_uid)
        .collection('meta')
        .doc('initial_expressions')
        .get();
    if (!doc.exists) return {};
    final data = (doc.data() ?? {}) as Map<String, dynamic>;
    final notes = (data['notes'] ?? {}) as Map<String, dynamic>;
    return notes.map((k, v) => MapEntry(k, (v ?? '').toString()));
  }

  /// 초기 표정 노트 스트림
  Stream<Map<String, String>> initialExpressionsStream() {
    return _db
        .collection('users')
        .doc(_uid)
        .collection('meta')
        .doc('initial_expressions')
        .snapshots()
        .map((snap) {
      if (!snap.exists) return <String, String>{};
      final data = (snap.data() ?? {}) as Map<String, dynamic>;
      final notes = (data['notes'] ?? {}) as Map<String, dynamic>;
      return notes.map((k, v) => MapEntry(k, (v ?? '').toString()));
    });
  }
}