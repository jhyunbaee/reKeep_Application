import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  // 애플 로그인
  Future<String> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      // 디버그: 토큰이 제대로 왔는지 확인
      print('=== APPLE DEBUG ===');
      print('identityToken null? ${appleCredential.identityToken == null}');
      print('authCode null? ${appleCredential.authorizationCode == null}');
      print('rawNonce length: ${rawNonce.length}');

      if (appleCredential.identityToken == null) {
        return "애플 토큰을 받지 못했습니다 (identityToken null)";
      }

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);
      final user = userCredential.user;
      if (user == null) return "에러가 발생했습니다.";

      // 신규 유저면 Firestore에 저장
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        final displayName = [
          appleCredential.familyName,
          appleCredential.givenName,
        ].where((e) => e != null && e.isNotEmpty).join('');
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': user.email ?? appleCredential.email ?? '',
          'name': displayName.isNotEmpty ? displayName : '사용자',
          'nickname': displayName.isNotEmpty ? displayName : '사용자',
          'createdAt': DateTime.now(),
        });
      }
      return "success";
    } on SignInWithAppleAuthorizationException catch (e) {
      // 사용자가 취소한 경우
      if (e.code == AuthorizationErrorCode.canceled) {
        return "cancelled";
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // 애플 로그인용 nonce 생성
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
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
