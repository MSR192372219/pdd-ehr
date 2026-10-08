import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/firestore_helper.dart';

class PatProfilePage extends StatefulWidget {
  final String uid;

  const PatProfilePage({
    super.key,
    this.uid = '',
  });

  @override
  State<PatProfilePage> createState() => _PatProfilePageState();
}

class _PatProfilePageState extends State<PatProfilePage> {
  FirebaseFirestore get _db => FirestoreHelper.db;

  late String _currentUid;
  Map<String, dynamic>? _data;
  bool _isLoading = true;
  String? _error;
  bool _isEditing = false;

  // Editable fields
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _allergiesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    _currentUid = currentUser?.uid ?? widget.uid;
    _loadProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _allergiesController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Read from patients/{uid}
      final doc = await _db.collection('patients').doc(_currentUid).get();
      if (doc.exists && doc.data() != null) {
        if (!mounted) return;
        setState(() {
          _data = doc.data()!;
          _isLoading = false;
        });
        _syncControllers();
        return;
      }

      // Fallback: users/{uid}
      final userDoc = await _db.collection('users').doc(_currentUid).get();
      if (userDoc.exists && userDoc.data() != null) {
        if (!mounted) return;
        setState(() {
          _data = userDoc.data()!;
          _isLoading = false;
        });
        _syncControllers();
        return;
      }

      if (!mounted) return;
      setState(() {
        _error = 'Profile not found for this account.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _syncControllers() {
    _phoneController.text = _data?['phone']?.toString() ?? '';
    _addressController.text = _data?['address']?.toString() ?? '';
    _allergiesController.text = _data?['allergies']?.toString() ?? '';
  }

  Future<void> _saveProfile() async {
    // Only save patient-editable fields — NEVER modify role, patientId, uid
    final updates = <String, dynamic>{
      'phone': _phoneController.text.trim(),
      'address': _addressController.text.trim(),
      'allergies': _allergiesController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _db.collection('patients').doc(_currentUid).update(updates);

      // Also update phone in users/{uid} for consistency
      try {
        await _db.collection('users').doc(_currentUid).update({
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (!mounted) return;
      setState(() => _isEditing = false);
      _loadProfile();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated successfully'),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update profile: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0FA),
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading && _error == null && !_isEditing)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
              onPressed: () => setState(() => _isEditing = true),
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel',
              onPressed: () {
                _syncControllers();
                setState(() => _isEditing = false);
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadProfile,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeader(),
                      const Divider(height: 32),
                      if (_isEditing) ..._buildEditableFields() else ..._buildReadOnlyFields(),
                      if (_isEditing) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _saveProfile,
                            icon: const Icon(Icons.save),
                            label: const Text('Save Changes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple[700],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    final name = _data?['name']?.toString() ?? 'Patient';
    final pId = _data?['patientId']?.toString() ?? '';
    final status = _data?['status']?.toString() ?? 'active';

    return Column(
      children: [
        CircleAvatar(
          radius: 44,
          backgroundColor: Colors.purple[100],
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'P',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Colors.purple[700],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (pId.isNotEmpty) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Patient ID: $pId',
              style: TextStyle(
                color: Colors.purple[800],
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: status == 'active' ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            status.toUpperCase(),
            style: TextStyle(
              color: status == 'active' ? Colors.green[700] : Colors.red[700],
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildReadOnlyFields() {
    final email = _data?['email']?.toString() ?? '';
    final phone = _data?['phone']?.toString() ?? 'Not specified';
    final age = _data?['age']?.toString() ?? 'N/A';
    final gender = _data?['gender']?.toString() ?? 'N/A';
    final blood = _data?['bloodGroup']?.toString() ?? 'N/A';
    final address = _data?['address']?.toString() ?? 'Not specified';
    final allergies = _data?['allergies']?.toString() ?? '';
    final dob = _data?['dateOfBirth']?.toString() ?? '';

    return [
      _infoTile(Icons.email, 'Email', email.isNotEmpty ? email : 'Not set'),
      _infoTile(Icons.phone, 'Phone', phone),
      _infoTile(Icons.cake, 'Age', age),
      if (dob.isNotEmpty) _infoTile(Icons.calendar_today, 'Date of Birth', dob),
      _infoTile(Icons.person, 'Gender', gender),
      _infoTile(Icons.bloodtype, 'Blood Group', blood),
      _infoTile(Icons.location_on, 'Address', address),
      if (allergies.isNotEmpty) _infoTile(Icons.warning_amber, 'Allergies', allergies),
    ];
  }

  List<Widget> _buildEditableFields() {
    return [
      // Non-editable fields shown as read-only
      _infoTile(Icons.email, 'Email (read-only)', _data?['email']?.toString() ?? 'Not set'),
      _infoTile(Icons.cake, 'Age (read-only)', _data?['age']?.toString() ?? 'N/A'),
      _infoTile(Icons.person, 'Gender (read-only)', _data?['gender']?.toString() ?? 'N/A'),
      _infoTile(Icons.bloodtype, 'Blood Group (read-only)', _data?['bloodGroup']?.toString() ?? 'N/A'),
      const SizedBox(height: 8),
      // Editable fields
      _editableField(Icons.phone, 'Phone', _phoneController),
      const SizedBox(height: 12),
      _editableField(Icons.location_on, 'Address', _addressController),
      const SizedBox(height: 12),
      _editableField(Icons.warning_amber, 'Allergies', _allergiesController),
    ];
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(icon, color: Colors.purple[700]),
        title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
    );
  }

  Widget _editableField(IconData icon, String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.purple[700]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.purple[700]!, width: 2),
        ),
      ),
    );
  }
}
