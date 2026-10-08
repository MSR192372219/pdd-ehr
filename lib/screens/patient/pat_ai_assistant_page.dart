import 'package:flutter/material.dart';
import '../../services/api/ai_api_service.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String> keyPoints;
  final String? disclaimer;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.keyPoints = const [],
    this.disclaimer,
  });
}

/// Interactive Grounded AI Health Assistant Screen for Patients.
class PatAiAssistantPage extends StatefulWidget {
  final String? patientId;
  final String? patientName;

  const PatAiAssistantPage({
    super.key,
    this.patientId,
    this.patientName,
  });

  @override
  State<PatAiAssistantPage> createState() => _PatAiAssistantPageState();
}

class _PatAiAssistantPageState extends State<PatAiAssistantPage> {
  final AIApiService _aiApi = AIApiService();
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _isLoading = false;

  final List<String> _suggestions = [
    'Summarize my recent medical history',
    'Explain my current prescription',
    'What precautions should I follow for my condition?',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage(
        text: 'Hello! I am your AI Health Assistant. I can help explain your authorized medical records and prescriptions in clear, simple language. What would you like to review today?',
        isUser: false,
        timestamp: DateTime.now(),
        disclaimer: 'AI-generated assistance is educational only. Consult your physician for medical decisions.',
      ),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty || _isLoading) return;

    _queryController.clear();
    setState(() {
      _messages.add(_ChatMessage(
        text: trimmed,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final res = await _aiApi.askAssistant(trimmed);
      if (!mounted) return;

      if (res.success && res.data != null) {
        final d = res.data!;
        final points = (d['key_points'] is List)
            ? (d['key_points'] as List).map((e) => e.toString()).toList()
            : <String>[];

        setState(() {
          _isLoading = false;
          _messages.add(_ChatMessage(
            text: d['answer']?.toString() ?? 'No response received.',
            isUser: false,
            timestamp: DateTime.now(),
            keyPoints: points,
            disclaimer: d['disclaimer']?.toString(),
          ));
        });
      } else {
        setState(() {
          _isLoading = false;
          _messages.add(_ChatMessage(
            text: res.errorMessage ?? 'Unable to connect to AI Assistant. Please try again.',
            isUser: false,
            timestamp: DateTime.now(),
            disclaimer: 'Service notice.',
          ));
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          text: 'Network error communicating with AI Assistant: $e',
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }

    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F5FC),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, size: 20),
            SizedBox(width: 8),
            Text('AI Health Assistant', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Safety Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.amber.shade100,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.brown.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'AI assistance is educational only and does not replace your doctor\'s diagnosis.',
                    style: TextStyle(fontSize: 11, color: Colors.brown.shade900, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Message List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Consulting authorized clinical context...',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Suggestion Chips (shown when few messages)
          if (_messages.length <= 3 && !_isLoading)
            Container(
              height: 38,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _suggestions.length,
                itemBuilder: (context, i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(_suggestions[i], style: const TextStyle(fontSize: 11)),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.purple.shade200),
                      onPressed: () => _sendMessage(_suggestions[i]),
                    ),
                  );
                },
              ),
            ),

          // Input Bar
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE5E0F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    onSubmitted: _sendMessage,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(
                      hintText: 'Ask about your records or prescriptions...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      filled: true,
                      fillColor: const Color(0xFFF5F3FA),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  icon: const Icon(Icons.send, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isLoading ? null : () => _sendMessage(_queryController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12, left: 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.purple.shade700,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 36),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Colors.purple),
                const SizedBox(width: 6),
                Text(
                  'AI Assistant',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.purple.shade800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              msg.text,
              style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.35),
            ),
            if (msg.keyPoints.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...msg.keyPoints.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• $p', style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                  )),
            ],
            if (msg.disclaimer != null) ...[
              const SizedBox(height: 10),
              Text(
                msg.disclaimer!,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
