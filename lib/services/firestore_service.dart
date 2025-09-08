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

    // 1) 서브컬렉션(sessions 등) 안전 삭제 (비어 있어도 문제 없게)
    Future<void> _deleteCollection(CollectionReference<Map<String, dynamic>> col) async {
      const int batchSize = 300; // 500 제한보다 낮게
      Query<Map<String, dynamic>> query = col.limit(batchSize);

      while (true) {
        final snap = await query.get();
        if (snap.docs.isEmpty) break;

        final batch = _db.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        if (snap.docs.length < batchSize) break; // 더 없음
      }
    }

    try {
      final sessionsCol = userRef.collection('sessions');
      await _deleteCollection(sessionsCol);
    } catch (_) {
      // 컬렉션이 없거나 권한 문제 시에도 탈퇴는 계속 진행
    }

    // 2) 최상위 user 문서 삭제 (없어도 그냥 통과)
    try {
      await userRef.delete();
    } on FirebaseException catch (e) {
      if (e.code != 'not-found' && e.code != 'permission-denied') {
        rethrow; // 정말 이상한 경우만 올림
      }
    } catch (_) {/* 무시 */}
  }

  Future<void> _deleteAllStorage(String uid) async {
    // 예: users/{uid}/ 이하 모든 파일 삭제, 폴더가 없어도 그냥 통과
    final base = _storage.ref().child('users/$uid');

    Future<void> _deleteFolder(Reference folder) async {
      try {
        final listing = await folder.listAll(); // 폴더 없으면 아래 catch로 떨어질 수 있음
        for (final item in listing.items) {
          try {
            await item.delete();
          } catch (_) {/* 개별 파일 삭제 실패 무시 */}
        }
        for (final prefix in listing.prefixes) {
          await _deleteFolder(prefix);
        }
        // 마지막에 폴더 자체는 삭제 개념이 없으니 패스
      } on FirebaseException catch (e) {
        // 경로가 아예 없으면 object-not-found 발생 가능 → 그냥 무시
        if (e.code != 'object-not-found') {
          // 다른 에러는 상황 봐서 처리, 여기선 통과
        }
      } catch (_) {/* 무시 */}
    }

    await _deleteFolder(base);
  }
}
