import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> signUpUser({
    required String email,
    required String password,
    required String name,
    String nickname = '',
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
          'nickname': nickname.isNotEmpty ? nickname : name,
          'createdAt': DateTime.now(),
        });
        result = "success:${cred.user!.uid}";
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
    await GoogleSignIn().signOut();
    await _auth.signOut();
  }

  // 구글 로그인
  Future<String> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return "cancelled";

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );
      final User? user = userCredential.user;
      if (user == null) return "에러가 발생했습니다.";

      // 신규 유저면 Firestore에 저장
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? '',
          'name': user.displayName ?? '',
          'nickname': user.displayName ?? '',
          'createdAt': DateTime.now(),
        });
      }
      return "success";
    } catch (e) {
      return e.toString();
    }
  }

  // 애플 로그인 - Apple Developer Program 가입 후 활성화 예정

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
