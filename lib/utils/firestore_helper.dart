import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class FirestoreHelper {
  static FirebaseFirestore? _activeInstance;

  /// Returns the single correctly configured Firestore instance for databaseId 'default'.
  static FirebaseFirestore get db {
    try {
      final defaultApp = Firebase.app();
      if (_activeInstance == null || _activeInstance!.app.name != defaultApp.name) {
        _activeInstance = FirebaseFirestore.instanceFor(
          app: defaultApp,
          databaseId: 'default',
        );
      }
      return _activeInstance!;
    } catch (e) {
      debugPrint('[FIRESTORE_HELPER] Error getting instance: $e. Re-initializing...');
      _activeInstance = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'default',
      );
      return _activeInstance!;
    }
  }

  /// Resets the cached Firestore instance
  static void reset() {
    _activeInstance = null;
  }

  /// Initializes the Firestore database target cleanly.
  static Future<void> initialize() async {
    final defaultApp = Firebase.app();
    _activeInstance = FirebaseFirestore.instanceFor(
      app: defaultApp,
      databaseId: 'default',
    );
    debugPrint('[FIRESTORE_HELPER] Primary database initialized to databaseId: "default" on app: "${defaultApp.name}"');
  }

  /// Performs a document read using the single configured Firestore database instance.
  static Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(
    String collection,
    String docId,
  ) async {
    try {
      return await db.collection(collection).doc(docId).get();
    } catch (e) {
      if (e.toString().contains('FirebaseApp was deleted')) {
        debugPrint('[FIRESTORE_HELPER] Caught deleted app error in getDoc. Resetting and retrying...');
        _activeInstance = null;
        return await db.collection(collection).doc(docId).get();
      }
      rethrow;
    }
  }

  /// Performs a collection query using the single configured Firestore database instance.
  static Future<QuerySnapshot<Map<String, dynamic>>> getCollection(
    String collection, {
    String? whereField,
    Object? isEqualTo,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = db.collection(collection);
      if (whereField != null && isEqualTo != null) {
        query = query.where(whereField, isEqualTo: isEqualTo);
      }
      if (limit != null) {
        query = query.limit(limit);
      }
      return await query.get();
    } catch (e) {
      if (e.toString().contains('FirebaseApp was deleted')) {
        debugPrint('[FIRESTORE_HELPER] Caught deleted app error in getCollection. Resetting and retrying...');
        _activeInstance = null;
        Query<Map<String, dynamic>> query = db.collection(collection);
        if (whereField != null && isEqualTo != null) {
          query = query.where(whereField, isEqualTo: isEqualTo);
        }
        if (limit != null) {
          query = query.limit(limit);
        }
        return await query.get();
      }
      rethrow;
    }
  }
}
