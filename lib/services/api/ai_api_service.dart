import 'api_client.dart';
import 'api_config.dart';

/// Service interfacing the Flutter mobile application with the Private Cloud AI Subsystem.
/// Enforces Firebase Authentication token transmission and server-authoritative data minimization.
class AIApiService {
  static final AIApiService _instance = AIApiService._internal();
  factory AIApiService() => _instance;
  AIApiService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Queries operational readiness, provider, and model of the AI subsystem.
  Future<ApiResponse<Map<String, dynamic>>> getAIStatus() async {
    return _apiClient.get(ApiConfig.aiV1Status, requireAuth: true);
  }

  /// Requests an authorized, data-minimized clinical summary of an EHR record.
  /// Enforces patient isolation: patients may only summarize their own records.
  Future<ApiResponse<Map<String, dynamic>>> summarizeRecord(String recordId) async {
    return _apiClient.post(
      ApiConfig.aiSummarize,
      {'record_id': recordId, 'record_type': 'medical_record'},
      requireAuth: true,
    );
  }

  /// Requests a patient-friendly pharmacological explanation of a prescription.
  /// Explains medication purpose, schedule guidance, and clinical precautions.
  Future<ApiResponse<Map<String, dynamic>>> explainPrescription({
    String? prescriptionId,
    String? medicineName,
    String? dosage,
    String? frequency,
    String? instructions,
    String? diagnosis,
  }) async {
    final body = <String, dynamic>{};
    if (prescriptionId != null) body['prescription_id'] = prescriptionId;
    if (medicineName != null) body['medicine_name'] = medicineName;
    if (dosage != null) body['dosage'] = dosage;
    if (frequency != null) body['frequency'] = frequency;
    if (instructions != null) body['instructions'] = instructions;
    if (diagnosis != null) body['diagnosis'] = diagnosis;

    return _apiClient.post(
      ApiConfig.aiPrescriptionExplain,
      body,
      requireAuth: true,
    );
  }

  /// Sends a grounded health inquiry to the AI Assistant.
  /// Bounded strictly to the caller's authorized health records.
  Future<ApiResponse<Map<String, dynamic>>> askAssistant(
    String query, {
    String? patientId,
  }) async {
    final body = <String, dynamic>{
      'query': query,
    };
    if (patientId != null) body['patient_id'] = patientId;

    return _apiClient.post(
      ApiConfig.aiAssistant,
      body,
      requireAuth: true,
    );
  }
}
