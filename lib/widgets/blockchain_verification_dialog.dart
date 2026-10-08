import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api/blockchain_api_service.dart';

/// Modal dialog performing and displaying cryptographic EHR integrity verification.
class BlockchainVerificationDialog extends StatefulWidget {
  final String recordId;
  final String recordTitle;

  const BlockchainVerificationDialog({
    super.key,
    required this.recordId,
    this.recordTitle = 'Medical Record',
  });

  static Future<void> show(
    BuildContext context, {
    required String recordId,
    String recordTitle = 'Medical Record',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => BlockchainVerificationDialog(
        recordId: recordId,
        recordTitle: recordTitle,
      ),
    );
  }

  @override
  State<BlockchainVerificationDialog> createState() => _BlockchainVerificationDialogState();
}

class _BlockchainVerificationDialogState extends State<BlockchainVerificationDialog> {
  final BlockchainApiService _blockchainApi = BlockchainApiService();

  bool _isLoading = true;
  bool? _verified;
  String _status = '';
  String? _transactionId;
  int? _blockNumber;
  String? _network;
  String? _timestamp;
  String? _currentHash;
  String? _onChainHash;
  String? _errorMessage;
  String? _details;

  @override
  void initState() {
    super.initState();
    _performVerification();
  }

  Future<void> _performVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _blockchainApi.verifyRecordIntegrity(
        recordId: widget.recordId,
      );

      if (!mounted) return;

      if (res.success && res.data != null) {
        final d = res.data!;
        setState(() {
          _isLoading = false;
          _verified = d['verified'] == true;
          _status = d['status']?.toString() ?? (_verified! ? 'INTEGRITY_VERIFIED' : 'INTEGRITY_MISMATCH');
          _transactionId = d['transaction_id']?.toString();
          _blockNumber = d['block_number'] is int ? d['block_number'] as int : null;
          _network = d['blockchain_network']?.toString() ?? 'LOCAL DEVELOPMENT BLOCKCHAIN (EVM)';
          _timestamp = d['timestamp']?.toString();
          _currentHash = d['current_hash']?.toString();
          _onChainHash = d['on_chain_hash']?.toString();
          _details = d['details']?.toString();
        });
      } else {
        setState(() {
          _isLoading = false;
          _verified = false;
          _errorMessage = res.errorMessage ?? 'Failed to connect to verification backend.';
          _status = 'ERROR';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _verified = false;
        _errorMessage = 'Verification error: $e';
        _status = 'ERROR';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.indigo, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Blockchain Integrity Check',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Record: ${widget.recordTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
            const Divider(height: 24),

            if (_isLoading) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Computing canonical SHA-256 hash & querying EVM smart contract...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 28),
            ] else if (_errorMessage != null) ...[
              // Error state
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verification Unavailable',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _errorMessage!,
                            style: TextStyle(fontSize: 12, color: Colors.red.shade800),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _performVerification,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry Verification'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ] else if (_verified == true) ...[
              // Success verified
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade300, width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '✓ Record Integrity Verified',
                            style: TextStyle(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The cryptographic digest of this clinical record perfectly matches the immutable proof anchored in the smart contract. Off-chain clinical data has not been modified.',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildProofMetaTile('Status', _status, Icons.check_circle_outline, Colors.green),
              _buildProofMetaTile('Algorithm', 'SHA-256 (Canonical)', Icons.lock_outline, Colors.blueGrey),
              if (_network != null)
                _buildProofMetaTile('Network', _network!, Icons.hub_outlined, Colors.purple),
              if (_blockNumber != null)
                _buildProofMetaTile('Confirmed Block', '#$_blockNumber', Icons.layers_outlined, Colors.indigo),
              if (_transactionId != null)
                _buildTxHashTile(_transactionId!),
              if (_timestamp != null)
                _buildProofMetaTile('Verified At', _timestamp!, Icons.schedule, Colors.grey),
            ] else ...[
              // Verification Failed / Tampering / Missing proof
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade600, width: 1.5),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '⚠ Integrity Verification Failed',
                            style: TextStyle(
                              color: Colors.brown.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _details ??
                          (_status == 'PROOF_NOT_FOUND'
                              ? 'No cryptographic integrity proof has been anchored on-chain for this record yet.'
                              : 'Current record hash differs from the blockchain registry. Possible unauthorized off-chain tampering detected.'),
                      style: TextStyle(fontSize: 12, color: Colors.brown.shade900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildProofMetaTile('Result Status', _status, Icons.report_problem_outlined, Colors.orange),
              if (_currentHash != null)
                _buildHashDetailTile('Current Computed Hash', _currentHash!),
              if (_onChainHash != null)
                _buildHashDetailTile('Anchored Ledger Hash', _onChainHash!),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofMetaTile(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTxHashTile(String txHash) {
    final display = txHash.length > 20
        ? '${txHash.substring(0, 10)}...${txHash.substring(txHash.length - 8)}'
        : txHash;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.receipt_long, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          const Text(
            'Tx Hash: ',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.blue),
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: txHash));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Transaction Hash copied to clipboard')),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(Icons.copy, size: 14, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHashDetailTile(String title, String hash) {
    final display = hash.length > 24
        ? '${hash.substring(0, 12)}...${hash.substring(hash.length - 12)}'
        : hash;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  Text(
                    display,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.black87),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 14),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: hash));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$title copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Modal dialog allowing authorized Doctors or Admins to author a blockchain integrity proof.
class BlockchainProofCreationDialog extends StatefulWidget {
  final String recordId;
  final String patientName;
  final String diagnosis;

  const BlockchainProofCreationDialog({
    super.key,
    required this.recordId,
    required this.patientName,
    required this.diagnosis,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String recordId,
    required String patientName,
    required String diagnosis,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BlockchainProofCreationDialog(
        recordId: recordId,
        patientName: patientName,
        diagnosis: diagnosis,
      ),
    );
  }

  @override
  State<BlockchainProofCreationDialog> createState() => _BlockchainProofCreationDialogState();
}

class _BlockchainProofCreationDialogState extends State<BlockchainProofCreationDialog> {
  final BlockchainApiService _blockchainApi = BlockchainApiService();

  bool _isSubmitting = false;
  bool _isSuccess = false;
  String? _transactionId;
  int? _blockNumber;
  String? _network;
  String? _errorMessage;

  Future<void> _submitProof() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final res = await _blockchainApi.createIntegrityProof(
        recordId: widget.recordId,
      );

      if (!mounted) return;

      if (res.success && res.data != null) {
        final d = res.data!;
        setState(() {
          _isSubmitting = false;
          _isSuccess = true;
          _transactionId = d['transaction_id']?.toString();
          _blockNumber = d['block_number'] is int ? d['block_number'] as int : null;
          _network = d['blockchain_network']?.toString() ?? 'LOCAL DEVELOPMENT BLOCKCHAIN (EVM)';
        });
      } else {
        setState(() {
          _isSubmitting = false;
          _isSuccess = false;
          _errorMessage = res.errorMessage ?? 'Blockchain transaction failed.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isSuccess = false;
        _errorMessage = 'Error submitting transaction: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(22),
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.link, color: Colors.green, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Anchor to Blockchain',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!_isSubmitting)
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(_isSuccess),
                  ),
              ],
            ),
            const Divider(height: 24),

            if (_isSubmitting) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Computing SHA-256 digest & mining transaction on EVM registry smart contract...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 20),
            ] else if (_isSuccess) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Proof Confirmed On-Chain',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'The SHA-256 digest has been successfully minted to the EHRIntegrityRegistry smart contract. Off-chain clinical data remains confidential.',
                      style: TextStyle(fontSize: 12, color: Colors.green.shade900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_network != null)
                Text('Network: $_network', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              if (_blockNumber != null)
                Text('Confirmed Block: #$_blockNumber', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              if (_transactionId != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Tx: $_transactionId',
                  style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.blueGrey),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Done'),
              ),
            ] else ...[
              Text(
                'You are creating an immutable cryptographic integrity proof for:',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Patient: ${widget.patientName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('Diagnosis: ${widget.diagnosis}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Actual medical records remain strictly off-chain. Only the deterministic SHA-256 hash is anchored.',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _submitProof,
                      icon: const Icon(Icons.lock_clock),
                      label: const Text('Anchor Proof'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
