import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../utils/firestore_helper.dart';

class DoctorAccountResult {
  final String uid;
  final String doctorId;
  final String name;
  final String email;
  final String status;
  final String specialization;

  DoctorAccountResult({
    required this.uid,
    required this.doctorId,
    required this.name,
    required this.email,
    required this.status,
    required this.specialization,
  });
}

class DoctorService {
  static FirebaseFirestore get _db => FirestoreHelper.db;

  /// Provisions a Firebase Auth account for an existing doctor document.
  ///
  /// Security model & Admin Session Isolation:
  ///   1. Admin is signed in on primary FirebaseAuth.instance.
  ///   2. Doctor Auth account is created using an ISOLATED temporary secondary FirebaseApp.
  ///   3. Temporary secondary FirebaseApp is immediately signed out and deleted.
  ///   4. Primary FirebaseAuth.instance.currentUser remains the Admin throughout.
  ///   5. Primary FirebaseApp is NEVER deleted and Firestore never touches the secondary app.
  ///   6. Firestore records (users/{uid} and doctors/{docId}) are written via primary admin session.
  ///   7. Password is NEVER stored in Firestore, source code, or logs.
  static Future<DoctorAccountResult> provisionAuthForExistingDoctor({
    required String doctorDocId,
    required String email,
    required String password,
    required Map<String, dynamic> existingData,
  }) async {
    final String cleanEmail = email.trim().toLowerCase();
    final String cleanPassword = password.trim();
    final String cleanName = (existingData['name'] ?? 'Doctor').toString().trim();
    final String specialization = (existingData['specialization'] ?? 'General').toString().trim();
    final String department = (existingData['department'] ?? '').toString().trim();
    final String phone = (existingData['phone'] ?? '').toString().trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      throw Exception('Email and password are required to provision login account.');
    }

    if (cleanPassword.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    // 1. Verify admin session is active before proceeding
    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) {
      throw Exception('Admin session expired. Please log in again.');
    }
    final adminUidBefore = adminUser.uid;

    // 2. Verify doctor record is not already linked
    final existingUid = existingData['uid']?.toString().trim() ?? '';
    if (existingUid.isNotEmpty) {
      throw Exception('This doctor already has a linked Auth account (UID: $existingUid).');
    }

    // 3. Pre-check: Verify email does not already exist in Firestore 'users' collection
    final existingUserQuery = await _db
        .collection('users')
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (existingUserQuery.docs.isNotEmpty) {
      final existingUserDoc = existingUserQuery.docs.first;
      final existingRole = existingUserDoc.data()['role'] ?? 'unknown';
      throw Exception(
        'An account with email "$cleanEmail" already exists in the system (Role: $existingRole, UID: ${existingUserDoc.id}). Cannot provision a duplicate account.',
      );
    }

    // 4. Create doctor Firebase Auth account using an ISOLATED secondary FirebaseApp
    final appName = 'DoctorProvisionApp_${DateTime.now().microsecondsSinceEpoch}';
    final secondaryApp = await Firebase.initializeApp(
      name: appName,
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: cleanPassword,
      );

      final newUid = credential.user?.uid;
      if (newUid == null) {
        throw Exception('Failed to obtain Firebase Auth UID for doctor.');
      }

      // 5. Dispose secondary app immediately — no Firestore instance touches it
      await secondaryAuth.signOut();
      await secondaryApp.delete();

      final timestamp = FieldValue.serverTimestamp();

      // 6. Create users/{newUid} under primary Admin Firestore session
      final userData = {
        'uid': newUid,
        'email': cleanEmail,
        'name': cleanName,
        'role': 'doctor',
        'status': 'active',
        'doctorId': doctorDocId,
        'specialization': specialization,
        'department': department,
        'phone': phone,
        'createdAt': timestamp,
        'updatedAt': timestamp,
      };
      await _db.collection('users').doc(newUid).set(userData);

      // 7. Link doctor profile doctors/{doctorDocId} under primary Admin Firestore session
      final doctorUpdate = {
        'uid': newUid,
        'email': cleanEmail,
        'role': 'doctor',
        'updatedAt': timestamp,
      };
      await _db.collection('doctors').doc(doctorDocId).update(doctorUpdate);

      // 8. Assert Admin session is unchanged
      final adminUserAfter = FirebaseAuth.instance.currentUser;
      if (adminUserAfter == null || adminUserAfter.uid != adminUidBefore) {
        debugPrint('[DOCTOR_SERVICE] WARNING: Admin session UID mismatch after doctor provisioning!');
      } else {
        debugPrint('[DOCTOR_SERVICE] Admin session verified intact: ${adminUserAfter.uid}');
      }

      return DoctorAccountResult(
        uid: newUid,
        doctorId: doctorDocId,
        name: cleanName,
        email: cleanEmail,
        status: 'active',
        specialization: specialization,
      );
    } on FirebaseAuthException catch (e) {
      try {
        await secondaryApp.delete();
      } catch (_) {}

      if (e.code == 'email-already-in-use') {
        throw Exception(
          'The email "$cleanEmail" already exists in Firebase Authentication, but is not linked to this doctor record. To prevent account collision, please check Firebase Authentication or use a different email.',
        );
      } else if (e.code == 'weak-password') {
        throw Exception('The temporary password is too weak. Please use a stronger password.');
      } else if (e.code == 'invalid-email') {
        throw Exception('The email address "$cleanEmail" is invalid.');
      } else {
        throw Exception('Firebase Auth Error [${e.code}]: ${e.message ?? e.toString()}');
      }
    } catch (e) {
      try {
        await secondaryApp.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Updates doctor profile in both doctors/{docId} and users/{uid} if linked.
  static Future<void> updateDoctor({
    required String docId,
    required Map<String, dynamic> data,
    String? linkedUid,
  }) async {
    final timestamp = FieldValue.serverTimestamp();
    final updatedData = Map<String, dynamic>.from(data);
    updatedData['updatedAt'] = timestamp;
    updatedData.remove('role');
    updatedData.remove('password');

    await _db.collection('doctors').doc(docId).update(updatedData);

    final uid = linkedUid ?? data['uid']?.toString();
    if (uid != null && uid.isNotEmpty) {
      final userUpdate = <String, dynamic>{'updatedAt': timestamp};
      if (data.containsKey('name')) userUpdate['name'] = data['name'];
      if (data.containsKey('email')) userUpdate['email'] = data['email'];
      if (data.containsKey('specialization')) userUpdate['specialization'] = data['specialization'];
      if (data.containsKey('department')) userUpdate['department'] = data['department'];
      if (data.containsKey('phone')) userUpdate['phone'] = data['phone'];

      try {
        await _db.collection('users').doc(uid).update(userUpdate);
      } catch (e) {
        debugPrint('[DOCTOR_SERVICE] Optional users/$uid update notice: $e');
      }
    }
  }
}
