import 'package:flutter/foundation.dart';

/// Centralized configuration for the Private Cloud Backend API client.
/// Automatically detects platform-appropriate loopback addresses for local testing.
class ApiConfig {
  /// Default local development port matching backend/app/core/config.py
  static const int port = 8000;

  /// Private Cloud Backend Base URL
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:$port';
    }
    // Android emulator loops back to host machine via 10.0.2.2
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$port';
    }
    // Windows, macOS, Linux, iOS Simulator
    return 'http://127.0.0.1:$port';
  }

  // API Version Prefix
  static const String apiV1 = '/api/v1';

  // API Endpoints
  static const String rootHealth = '/health';
  static const String v1Health = '$apiV1/health';
  static const String ehrRecords = '$apiV1/ehr/records';
  static const String ehrAudit = '$apiV1/ehr/audit';
  static const String aiStatus = '$apiV1/ehr/ai/status';
  static const String blockchainStatus = '$apiV1/ehr/blockchain/status';
  static const String blockchainV1Status = '$apiV1/blockchain/status';
  static const String blockchainVerify = '$apiV1/blockchain/verify';
  static const String blockchainProof = '$apiV1/blockchain/proof';
  static const String aiV1Status = '$apiV1/ai/status';
  static const String aiSummarize = '$apiV1/ai/summarize';
  static const String aiPrescriptionExplain = '$apiV1/ai/prescription-explanation';
  static const String aiAssistant = '$apiV1/ai/assistant';

  // Network Timeout Configuration
  static const Duration connectTimeout = Duration(seconds: 15);
}
