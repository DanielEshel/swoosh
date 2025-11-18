import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


Future<void> ensureUserDoc(User user) async {
  final docRef =
      FirebaseFirestore.instance.collection('users').doc(user.uid);

  final snapshot = await docRef.get();

  if (!snapshot.exists) {
    // User signed up on this device OR somewhere else but no Firestore doc yet
    await docRef.set({
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
      'provider': user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : 'password',
    });
  } else {
    // User doc already exists → just update last login
    await docRef.update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }
}
