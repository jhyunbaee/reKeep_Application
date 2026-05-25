import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> signUpUser({
    required String email,
    required String password,
    required String name,
  }) async {
    String result = "에러가 발생했습니다.";
    try {
      if (email.isNotEmpty && password.isNotEmpty && name.isNotEmpty) {
        UserCredential cred = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        await _firestore.collection('users').doc(cred.user!.uid).set({
          'uid': cred.user!.uid,
          'email': email,
          'name': name,
          'nickname': name,
          'createdAt': DateTime.now(),
        });
        result = "success";
      } else {
        result = "모든 필드를 입력해주세요.";
      }
    } on FirebaseAuthException catch (e) {
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

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String> loginUser({
    required String email,
    required String password,
  }) async {
    String result = "에러가 발생했습니다.";
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        result = "success";
      } else {
        result = "이메일과 비밀번호를 모두 입력해주세요.";
      }
    } on FirebaseAuthException catch (e) {
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
