const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * Trusted Callable Cloud Function to generate a new Patient ID.
 * Verifies that the caller is an authenticated Admin with status = active.
 * Uses Firebase Admin SDK to atomically increment counters/patient_id_counter.
 */
exports.generatePatientId = functions.https.onCall(async (data, context) => {
  // 1. Verify caller authentication
  if (!context.auth) {
    throw new functions.https.HttpsError(
      "unauthenticated",
      "The function must be called while authenticated."
    );
  }

  const callerUid = context.auth.uid;
  const db = admin.firestore();

  // 2. Verify caller Admin authorization
  const callerDoc = await db.collection("users").doc(callerUid).get();
  if (!callerDoc.exists) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "User profile does not exist."
    );
  }

  const callerData = callerDoc.data();
  if (callerData.role !== "admin" || callerData.status !== "active") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "Only active hospital Administrators can generate Patient IDs."
    );
  }

  // 3. Execute atomic transaction on counters/patient_id_counter using Firebase Admin SDK
  const counterRef = db.collection("counters").doc("patient_id_counter");

  const newPatientId = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(counterRef);
    let currentMax = 0;

    if (snapshot.exists && snapshot.data()) {
      currentMax = snapshot.data().current || 0;
    } else {
      // Seed counter once if doc doesn't exist by finding max integer suffix in patients
      const snap = await db.collection("patients").get();
      snap.forEach((doc) => {
        const existingId = doc.data().patientId || "";
        if (typeof existingId === "string" && existingId.toUpperCase().startsWith("P")) {
          const numPart = parseInt(existingId.substring(1), 10);
          if (!isNaN(numPart) && numPart > currentMax) {
            currentMax = numPart;
          }
        }
      });
    }

    const nextNum = currentMax + 1;
    transaction.set(
      counterRef,
      {
        current: nextNum,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return "P" + String(nextNum).padStart(6, "0");
  });

  return { patientId: newPatientId };
});
