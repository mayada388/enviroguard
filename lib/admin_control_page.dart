import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'login_page.dart';
import 'admin_system_monitoring_page.dart';
import 'admin_manage_sensors_page.dart';
import 'admin_set_thresholds_page.dart';
import 'admin_manage_device_page.dart';
import 'admin_device_maintenance_page.dart';
import 'admin_add_admin_page.dart';

class AdminControlPage extends StatelessWidget {
  const AdminControlPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Control')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('System Monitoring'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminSystemMonitoringPage()),
            ),
          ),
          ListTile(
            title: const Text('Manage Sensors'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminManageSensorsPage()),
            ),
          ),
          ListTile(
            title: const Text('Set Thresholds'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminSetThresholdsPage()),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Manage devices'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminManageDevicePage()),
            ),
          ),
          ListTile(
            title: const Text('Device maintenance'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminDeviceMaintenancePage()),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Add admin'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminAddAdminPage()),
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('Logout'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}