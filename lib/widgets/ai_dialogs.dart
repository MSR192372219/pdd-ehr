import 'package:flutter/material.dart';
import '../services/api/ai_api_service.dart';

/// Modal dialog providing an AI-generated clinical summary of an authorized EHR record.
class AISummaryDialog extends StatefulWidget {
  final String recordId;
  final String recordTitle;

  const AISummaryDialog({
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
      builder: (_) => AISummaryDialog(
        recordId: recordId,
        recordTitle: recordTitle,
      ),
    );
  }

  @override
  State<AISummaryDialog> createState() => _AISummaryDialogState();
}

class _AISummaryDialogState extends State<AISummaryDialog> {
  final AIApiService _aiApi = AIApiService();

  bool _isLoading = true;
  String? _summary;
  List<String> _keyPoints = [];
  String? _disclaimer;
  String? _provider;
  String? _model;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _aiApi.summarizeRecord(widget.recordId);
      if (!mounted) return;

      if (res.success && res.data != null) {
        final d = res.data!;
        setState(() {
          _isLoading = false;
          _summary = d['summary']?.toString();
          if (d['key_points'] is List) {
            _keyPoints = (d['key_points'] as List).map((e) => e.toString()).toList();
          }
          _disclaimer = d['disclaimer']?.toString();
          _provider = d['provider']?.toString();
          _model = d['model']?.toString();
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res.errorMessage ?? 'Unable to generate summary.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
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
        constraints: const BoxConstraints(maxWidth: 500),
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
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Clinical Summary',
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
                ),
              ],
            ),
            const Divider(height: 20),

            if (_isLoading) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator(color: Colors.purple)),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Analyzing authorized clinical record & generating summary...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 28),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red.shade900, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadSummary,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              ),
            ] else ...[
              // Model Badge
              if (_provider != null)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Engine: $_provider (${_model ?? "AI"})',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              // Summary Paragraph
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  _summary ?? 'No summary generated.',
                  style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                ),
              ),

              if (_keyPoints.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Key Clinical Highlights:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                ..._keyPoints.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                          Expanded(
                            child: Text(p, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          ),
                        ],
                      ),
                    )),
              ],

              const SizedBox(height: 14),
              // Safety Disclaimer
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _disclaimer ??
                            'This summary is AI-generated for informational assistance only and is not a medical diagnosis. The official EHR remains authoritative.',
                        style: TextStyle(fontSize: 11, color: Colors.brown.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
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
}

/// Modal dialog explaining a medication prescription with pharmacological context and safety precautions.
class AIPrescriptionExplanationDialog extends StatefulWidget {
  final String? prescriptionId;
  final String? medicineName;
  final String? dosage;
  final String? frequency;
  final String? instructions;
  final String? diagnosis;

  const AIPrescriptionExplanationDialog({
    super.key,
    this.prescriptionId,
    this.medicineName,
    this.dosage,
    this.frequency,
    this.instructions,
    this.diagnosis,
  });

  static Future<void> show(
    BuildContext context, {
    String? prescriptionId,
    String? medicineName,
    String? dosage,
    String? frequency,
    String? instructions,
    String? diagnosis,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AIPrescriptionExplanationDialog(
        prescriptionId: prescriptionId,
        medicineName: medicineName,
        dosage: dosage,
        frequency: frequency,
        instructions: instructions,
        diagnosis: diagnosis,
      ),
    );
  }

  @override
  State<AIPrescriptionExplanationDialog> createState() => _AIPrescriptionExplanationDialogState();
}

class _AIPrescriptionExplanationDialogState extends State<AIPrescriptionExplanationDialog> {
  final AIApiService _aiApi = AIApiService();

  bool _isLoading = true;
  String? _medicine;
  String? _explanation;
  String? _scheduleGuidance;
  List<String> _precautions = [];
  String? _disclaimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExplanation();
  }

  Future<void> _loadExplanation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _aiApi.explainPrescription(
        prescriptionId: widget.prescriptionId,
        medicineName: widget.medicineName,
        dosage: widget.dosage,
        frequency: widget.frequency,
        instructions: widget.instructions,
        diagnosis: widget.diagnosis,
      );

      if (!mounted) return;

      if (res.success && res.data != null) {
        final d = res.data!;
        setState(() {
          _isLoading = false;
          _medicine = d['medicine']?.toString();
          _explanation = d['explanation']?.toString();
          _scheduleGuidance = d['schedule_guidance']?.toString();
          if (d['precautions'] is List) {
            _precautions = (d['precautions'] as List).map((e) => e.toString()).toList();
          }
          _disclaimer = d['disclaimer']?.toString();
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res.errorMessage ?? 'Unable to retrieve explanation.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: $e';
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
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.medication_liquid, color: Colors.teal, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Medication Guide',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _medicine ?? (widget.medicineName ?? 'Prescription'),
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
                ),
              ],
            ),
            const Divider(height: 20),

            if (_isLoading) ...[
              const SizedBox(height: 28),
              const Center(child: CircularProgressIndicator(color: Colors.teal)),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'Retrieving pharmacological guidance & precautions...',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.black87),
                ),
              ),
              const SizedBox(height: 28),
            ] else if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade900)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadExplanation,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              ),
            ] else ...[
              // Purpose
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What this medication is for:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.teal.shade900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _explanation ?? '',
                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Schedule Guidance
              if (_scheduleGuidance != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, size: 16, color: Colors.blueGrey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _scheduleGuidance!,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Precautions
              if (_precautions.isNotEmpty) ...[
                const Text(
                  'Clinical Precautions & Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 6),
                ..._precautions.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle_outline, size: 14, color: Colors.teal),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(p, style: const TextStyle(fontSize: 12, color: Colors.black87)),
                          ),
                        ],
                      ),
                    )),
              ],

              const SizedBox(height: 12),
              // Safety Disclaimer
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline, size: 16, color: Colors.brown),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _disclaimer ??
                            'AI-generated explanation — follow the doctor\'s prescription. Do not modify or discontinue medication without consulting your doctor.',
                        style: TextStyle(fontSize: 11, color: Colors.brown.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
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
}
