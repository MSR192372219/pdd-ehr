import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../utils/firestore_helper.dart';

class PatientAccountResult {
  final String uid;
  final String patientId;
  final String name;
  final String email;
  final String status;

  PatientAccountResult({
    required this.uid,
    required this.patientId,
    required this.name,
    required this.email,
    required this.status,
  });
}

class PatientService {
  static FirebaseFirestore get _db => FirestoreHelper.db;

  /// Generates the next sequential human-readable Patient ID.
  ///
  /// Architecture:
  ///   - Uses a Firestore transaction on counters/patient_id_counter.
  ///   - The transaction executes under the CURRENTLY LOGGED-IN Admin's credentials.
  ///   - firestore.rules enforces isAdmin() on the counters collection:
  ///       allow read, write: if isAdmin();
  ///     meaning the rule server-side evaluates the user's users/{uid}.role == 'admin'
  ///     before permitting any write. Non-admin users receive PERMISSION_DENIED.
  ///   - This is NOT a client-trust model — the rule reads from the users collection
  ///     server-side to verify role, not from a client-supplied claim.
  ///
  /// NOTE: Cloud Functions (generatePatientId) have been prepared in functions/index.js
  /// for future deployment when the project is upgraded to the Blaze plan.
  /// When the Blaze plan is enabled, migrate to the Cloud Function by calling
  /// PatientService.generateNextPatientIdViaCloudFunction() instead.
  static Future<String> generateNextPatientId() async {
    final DocumentReference counterRef = _db.collection('counters').doc('patient_id_counter');

    return _db.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int currentMax = 0;

      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data() as Map<String, dynamic>;
        currentMax = (data['current'] as num?)?.toInt() ?? 0;
      } else {
        // One-time seeding: scan existing patients to find highest patient ID
        // before the counter document existed.
        final snap = await _db.collection('patients').get();
        for (var doc in snap.docs) {
          final existingId = doc.data()['patientId']?.toString() ?? '';
          if (existingId.toUpperCase().startsWith('P')) {
            final numPart = int.tryParse(existingId.substring(1));
            if (numPart != null && numPart > currentMax) {
              currentMax = numPart;
            }
          }
        }
      }

      final nextNum = currentMax + 1;
      transaction.set(
        counterRef,
        {
          'current': nextNum,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      return 'P${nextNum.toString().padLeft(6, '0')}';
    });
  }

  /// Creates a new Patient Firebase Auth account and Firestore records (users/{UID} & patients/{UID}).
  ///
  /// Security model:
  ///   1. Admin is signed in on the primary FirebaseAuth.instance.
  ///   2. generateNextPatientId() writes the counter under Admin's session.
  ///      Firestore Rules verify isAdmin() server-side — any non-admin caller is denied.
  ///   3. Patient Auth account is created using an ISOLATED secondary FirebaseApp.
  ///      The secondary app has its own auth session; it does NOT disturb the primary admin session.
  ///   4. Secondary app is disposed after patient profiles are written.
  ///   5. Primary FirebaseAuth.instance.currentUser remains the Admin throughout.
  static Future<PatientAccountResult> createPatientWithAuth({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String age,
    required String gender,
    required String bloodGroup,
    required String address,
  }) async {
    final String cleanEmail = email.trim().toLowerCase();
    final String cleanPassword = password.trim();
    final String cleanName = name.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty || cleanName.isEmpty) {
      throw Exception('Name, email, and password are required.');
    }

    // Verify admin session is still active before proceeding
    final adminUser = FirebaseAuth.instance.currentUser;
    if (adminUser == null) {
      throw Exception('Admin session expired. Please log in again.');
    }
    final adminUidBefore = adminUser.uid;

    // Step 1: Generate Patient ID (Admin-auth-gated via Firestore Rules)
    final patientId = await generateNextPatientId();

    // Step 2: Create patient Firebase Auth account using an ISOLATED secondary app.
    final appName = 'PatientCreationApp_${DateTime.now().microsecondsSinceEpoch}';
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
        throw Exception('Failed to obtain Firebase Auth UID for new patient.');
      }

      // Step 3: Dispose the temporary secondary auth app immediately.
      // Firestore NEVER touches secondaryApp, preventing any 'FirebaseApp was deleted' errors.
      await secondaryAuth.signOut();
      await secondaryApp.delete();

      final timestamp = FieldValue.serverTimestamp();

      // Step 4: Create users/{UID} via primary admin Firestore session
      final userData = {
        'uid': newUid,
        'email': cleanEmail,
        'name': cleanName,
        'role': 'patient',
        'status': 'active',
        'patientId': patientId,
        'createdAt': timestamp,
      };
      await _db.collection('users').doc(newUid).set(userData);

      // Step 5: Create patients/{UID} via primary admin Firestore session
      final patientData = {
        'uid': newUid,
        'patientId': patientId,
        'name': cleanName,
        'email': cleanEmail,
        'phone': phone.trim(),
        'age': age.trim(),
        'gender': gender,
        'bloodGroup': bloodGroup.trim(),
        'address': address.trim(),
        'role': 'patient',
        'status': 'active',
        'createdAt': timestamp,
      };
      await _db.collection('patients').doc(newUid).set(patientData);

      // Step 6: Assert the primary admin session is unchanged.
      final adminUserAfter = FirebaseAuth.instance.currentUser;
      if (adminUserAfter == null || adminUserAfter.uid != adminUidBefore) {
        debugPrint('[PATIENT_SERVICE] WARNING: Admin session UID mismatch after patient creation!');
      } else {
        debugPrint('[PATIENT_SERVICE] Admin session verified intact: ${adminUserAfter.uid}');
      }

      return PatientAccountResult(
        uid: newUid,
        patientId: patientId,
        name: cleanName,
        email: cleanEmail,
        status: 'active',
      );
    } catch (e) {
      try {
        await secondaryApp.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Provisions a Firebase Auth account for an existing patient document
  /// (e.g. srinu, Rahul Kumar, varun).
  ///
  /// CRITICAL: Preserves existing patientId — does NOT generate a new one.
  /// Only calls generateNextPatientId if the existing record has NO patientId at all.
  static Future<PatientAccountResult> provisionAuthForExistingPatient({
    required String existingDocId,
    required String email,
    required String password,
    required Map<String, dynamic> existingData,
  }) async {
    final String cleanEmail = email.trim().toLowerCase();
    final String cleanPassword = password.trim();
    final String cleanName = (existingData['name'] ?? 'Patient').toString().trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      throw Exception('Email and password are required to provision login account.');
    }

    // PRESERVE existing patientId — only generate a new one if completely absent
    String patientId = existingData['patientId']?.toString() ?? '';
    if (patientId.isEmpty) {
      patientId = await generateNextPatientId();
    }

    final appName = 'PatientProvisionApp_${DateTime.now().microsecondsSinceEpoch}';
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
        throw Exception('Failed to obtain Auth UID.');
      }

      // Dispose the temporary secondary auth app immediately — no Firestore instance touches it
      await secondaryAuth.signOut();
      await secondaryApp.delete();

      final timestamp = FieldValue.serverTimestamp();

      // Create users/{newUid} with preserved patientId using primary Firestore instance
      final userData = {
        'uid': newUid,
        'email': cleanEmail,
        'name': cleanName,
        'role': 'patient',
        'status': 'active',
        'patientId': patientId,
        'createdAt': timestamp,
      };
      await _db.collection('users').doc(newUid).set(userData);

      // Link patients/{newUid} preserving all existing fields + patientId using primary Firestore instance
      final updatedPatientData = Map<String, dynamic>.from(existingData);
      updatedPatientData['uid'] = newUid;
      updatedPatientData['patientId'] = patientId; // preserved, never regenerated
      updatedPatientData['email'] = cleanEmail;
      updatedPatientData['role'] = 'patient';
      updatedPatientData['status'] = 'active';
      updatedPatientData['updatedAt'] = timestamp;
      // Strip any accidental password fields from legacy data
      updatedPatientData.remove('password');

      await _db.collection('patients').doc(newUid).set(
        updatedPatientData,
        SetOptions(merge: true),
      );

      // Delete the old auto-generated unlinked doc if different from newUid
      if (existingDocId != newUid) {
        await _db.collection('patients').doc(existingDocId).delete();
      }

      return PatientAccountResult(
        uid: newUid,
        patientId: patientId,
        name: cleanName,
        email: cleanEmail,
        status: 'active',
      );
    } catch (e) {
      try {
        await secondaryApp.delete();
      } catch (_) {}
      rethrow;
    }
  }

  /// Updates an existing patient's Firestore profile. Never modifies patientId or role.
  static Future<void> updatePatient({
    required String docId,
    required Map<String, dynamic> data,
    String? linkedUid,
  }) async {
    final timestamp = FieldValue.serverTimestamp();
    final updatedData = Map<String, dynamic>.from(data);
    updatedData['updatedAt'] = timestamp;
    // Guarantee immutability — strip restricted fields from any update payload
    updatedData.remove('patientId');
    updatedData.remove('role');
    updatedData.remove('password');

    await _db.collection('patients').doc(docId).update(updatedData);

    final uid = linkedUid ?? data['uid']?.toString() ?? (docId.length > 20 ? docId : null);
    if (uid != null && uid.isNotEmpty) {
      final userUpdate = <String, dynamic>{'updatedAt': timestamp};
      if (data.containsKey('name')) userUpdate['name'] = data['name'];
      if (data.containsKey('email')) userUpdate['email'] = data['email'];

      try {
        await _db.collection('users').doc(uid).update(userUpdate);
      } catch (e) {
        debugPrint('[PATIENT_SERVICE] Optional users/$uid update notice: $e');
      }
    }
  }

  /// Safely deactivates or deletes a patient while preserving healthcare history.
  static Future<void> safeDeletePatient(String docId, {String? uid}) async {
    final targetUid = uid ?? docId;

    final appts = await _db
        .collection('appointments')
        .where('patientId', isEqualTo: targetUid)
        .get();
    final records = await _db
        .collection('medical_records')
        .where('patientId', isEqualTo: targetUid)
        .get();

    if (appts.docs.isNotEmpty || records.docs.isNotEmpty) {
      // Archive: deactivate to preserve medical history
      await _db.collection('patients').doc(docId).update({
        'status': 'inactive',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (uid != null && uid.isNotEmpty) {
        try {
          await _db.collection('users').doc(uid).update({
            'status': 'inactive',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
    } else {
      // No medical history — safe to fully delete
      await _db.collection('patients').doc(docId).delete();
      if (uid != null && uid != docId) {
        try {
          await _db.collection('patients').doc(uid).delete();
        } catch (_) {}
      }
    }
  }
}
