import 'api_client.dart';
import 'api_config.dart';

/// Service interfacing Flutter client with the Private Cloud Blockchain Integrity subsystem.
/// Facilitates off-chain EHR verification against on-chain smart contract cryptographic digests.
class BlockchainApiService {
  static final BlockchainApiService _instance = BlockchainApiService._internal();
  factory BlockchainApiService() => _instance;
  BlockchainApiService._internal();

  final ApiClient _apiClient = ApiClient();

  /// Queries the current health and network status of the Blockchain EVM registry.
  Future<ApiResponse<Map<String, dynamic>>> getBlockchainStatus() async {
    return _apiClient.get(ApiConfig.blockchainV1Status, requireAuth: false);
  }

  /// Verifies an off-chain EHR record against the on-chain SHA-256 integrity proof.
  /// Authenticates caller via Firebase ID Token (enforces RBAC patient isolation).
  Future<ApiResponse<Map<String, dynamic>>> verifyRecordIntegrity({
    required String recordId,
    String recordType = 'medical_record',
    int recordVersion = 1,
  }) async {
    return _apiClient.post(
      ApiConfig.blockchainVerify,
      {
        'record_id': recordId,
        'record_type': recordType,
        'record_version': recordVersion,
      },
      requireAuth: true,
    );
  }

  /// Anchors a medical record hash to the blockchain registry smart contract.
  /// Restricted to authorized Doctors and Admins.
  Future<ApiResponse<Map<String, dynamic>>> createIntegrityProof({
    required String recordId,
    String recordType = 'medical_record',
    int recordVersion = 1,
  }) async {
    return _apiClient.post(
      ApiConfig.blockchainProof,
      {
        'record_id': recordId,
        'record_type': recordType,
        'record_version': recordVersion,
      },
      requireAuth: true,
    );
  }

  /// Retrieves stored blockchain proof metadata for a specific record.
  Future<ApiResponse<Map<String, dynamic>>> getRecordProof(String recordId) async {
    return _apiClient.get(
      '${ApiConfig.apiV1}/blockchain/proof/$recordId',
      requireAuth: true,
    );
  }
}
