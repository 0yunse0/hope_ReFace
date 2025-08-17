import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// 이메일이 사용 가능한지 확인 (true면 사용 가능)
  Future<bool> isEmailAvailable(String email) async {
    final methods = await _auth.fetchSignInMethodsForEmail(email);
    return methods.isEmpty;
  }

  /// "중복확인"에서 호출: 계정 생성 + 인증메일 발송 (화면 유지, 로그아웃 안 함)
  Future<UserCredential> createUserAndSendVerification({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (cred.user != null && !(cred.user!.emailVerified)) {
      await cred.user!.sendEmailVerification();
    }
    // 선택: 유저 문서 초기 생성
    await _db.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'emailVerified': false,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return cred;
  }

  /// "회원가입" 버튼에서 호출: 인증 메일을 눌렀는지 최신 상태 확인
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    await user?.reload();
    return _auth.currentUser?.emailVerified == true;
  }

  Future<void> finalizeAfterVerified() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'emailVerified': true,
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<User> signInEnforcingVerification({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.reload();
    final user = _auth.currentUser!;
    if (!user.emailVerified) {
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: '이메일 인증 후 로그인할 수 있습니다.',
      );
    }
    return user;
  }

  /// 회원가입 후 인증 메일 전송
  Future<void> signUp(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    if (cred.user != null && !(cred.user!.emailVerified)) {
      await cred.user!.sendEmailVerification();
    }
  }

  /// 로그인: 성공 시 이메일 인증 여부를 반환 (기존 동작 유지; 미인증이어도 세션 유지)
  Future<bool> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    await cred.user?.reload(); // 최신 상태 반영
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: '현재 로그인된 사용자가 없습니다.',
      );
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
    await user.delete();
  }

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
