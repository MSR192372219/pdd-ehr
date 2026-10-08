import 'package:flutter/material.dart';
import '../login/login_page.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  bool _notificationsEnabled = true;
  bool _emailAlerts = false;
  bool _appointmentReminders = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Hospital Info
          _sectionHeader('Hospital Information'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _settingsTile(
                  Icons.local_hospital,
                  'Hospital Name',
                  'City Healthcare Hospital',
                  onTap: () => _showEditDialog(context, 'Hospital Name', 'City Healthcare Hospital'),
                ),
                const Divider(height: 1),
                _settingsTile(
                  Icons.location_on,
                  'Address',
                  '123 Health Street, Mumbai',
                  onTap: () => _showEditDialog(context, 'Address', '123 Health Street, Mumbai'),
                ),
                const Divider(height: 1),
                _settingsTile(
                  Icons.phone,
                  'Contact Number',
                  '+91 9000000000',
                  onTap: () => _showEditDialog(context, 'Contact Number', '+91 9000000000'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Admin Profile
          _sectionHeader('Admin Profile'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _settingsTile(
                  Icons.person,
                  'Admin Name',
                  'System Administrator',
                  onTap: () => _showEditDialog(context, 'Admin Name', 'System Administrator'),
                ),
                const Divider(height: 1),
                _settingsTile(
                  Icons.email,
                  'Admin Email',
                  'admin@healthcare.com',
                  onTap: () => _showEditDialog(context, 'Admin Email', 'admin@healthcare.com'),
                ),
                const Divider(height: 1),
                _settingsTile(
                  Icons.lock,
                  'Change Password',
                  'Update your password',
                  onTap: () => _showChangePasswordDialog(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Notification Preferences
          _sectionHeader('Notification Preferences'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications),
                  title: const Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Receive in-app notifications'),
                  value: _notificationsEnabled,
                  onChanged: (v) => setState(() => _notificationsEnabled = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.email),
                  title: const Text('Email Alerts', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Receive email for important events'),
                  value: _emailAlerts,
                  onChanged: (v) => setState(() => _emailAlerts = v),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.calendar_month),
                  title: const Text('Appointment Reminders', style: TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: const Text('Get reminded about upcoming appointments'),
                  value: _appointmentReminders,
                  onChanged: (v) => setState(() => _appointmentReminders = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // App Info
          _sectionHeader('App Information'),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                _settingsTile(Icons.info_outline, 'Version', '1.0.0'),
                const Divider(height: 1),
                _settingsTile(Icons.description, 'Privacy Policy', 'View policy'),
                const Divider(height: 1),
                _settingsTile(Icons.gavel, 'Terms of Service', 'View terms'),
              ],
            ),
          ),
          const SizedBox(height: 30),

          // Logout
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _settingsTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[600]),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
      trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
      onTap: onTap,
    );
  }

  void _showEditDialog(BuildContext context, String field, String currentValue) {
    final ctrl = TextEditingController(text: currentValue);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit $field'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(
            labelText: field,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$field updated')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password updated successfully')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
