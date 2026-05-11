import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  // Firebase 인스턴스 가져오기
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 회원가입 함수
  Future<String> signUpUser({
    required String email,
    required String password,
    required String name,
  }) async {
    String result = "에러가 발생했습니다.";
    try {
      if (email.isNotEmpty && password.isNotEmpty && name.isNotEmpty) {
        // 1. Firebase Auth에 사용자 등록
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // auth_service.dart의 signUpUser 함수 내부 수정
        await _firestore.collection('users').doc(cred.user!.uid).set({
          'uid': cred.user!.uid,
          'email': email,
          'name': name,
          'nickname': name, // 초기 닉네임은 이름과 동일하게 설정하거나 빈 값으로 설정
          'createdAt': DateTime.now(),
        });
        result = "success";
      } else {
        result = "모든 필드를 입력해주세요.";
      }
    } on FirebaseAuthException catch (e) {
      // Firebase 인증 에러 처리 (비밀번호 취약, 이미 존재하는 이메일 등)
      if (e.code == 'invalid-email') {
        result = "이메일 형식이 잘못되었습니다.";
      } else if (e.code == 'weak-password') {
        result = "비밀번호가 너무 취약합니다.";
      } else if (e.code == 'email-already-in-use') {
        result = "이미 사용 중인 이메일입니다.";
      } else {
        result = e.message ?? "인증 에러가 발생했습니다.";
      }
    } catch (e) {
      result = e.toString();
    }
    return result;
  }

  /// 로그아웃 함수 (나중에 필요함)
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// 로그인 함수 (추가됨)
  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String result = "에러가 발생했습니다.";
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        // Firebase Auth를 통해 로그인 시도
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        result = "success";
      } else {
        result = "이메일과 비밀번호를 모두 입력해주세요.";
      }
    } on FirebaseAuthException catch (e) {
      // 로그인 실패 시 구체적인 에러 처리
      if (e.code == 'user-not-found') {
        result = "등록되지 않은 이메일입니다.";
      } else if (e.code == 'wrong-password') {
        result = "비밀번호가 틀렸습니다.";
      } else if (e.code == 'invalid-email') {
        result = "이메일 형식이 유효하지 않습니다.";
      } else {
        result = e.message ?? "로그인 중 에러가 발생했습니다.";
      }
    } catch (e) {
      result = e.toString();
    }
    return result;
  }
}
