import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDeviceMaintenancePage extends StatelessWidget {
  const AdminDeviceMaintenancePage({super.key});

  // اسم الكوليكشن
  CollectionReference<Map<String, dynamic>> get _devicesRef =>
      FirebaseFirestore.instance.collection('devices');

  // تنسيق التاريخ
  String _formatTimestamp(dynamic value) {
    if (value == null) return 'Never';

    DateTime? dt;
    if (value is Timestamp) {
      dt = value.toDate();
    } else if (value is DateTime) {
      dt = value;
    }

    if (dt == null) return 'Never';

    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');

    return '$y-$m-$d  $hh:$mm';
  }

  // تحويل الحالة ON / OFF
  bool _isOn(dynamic status) {
    if (status is bool) return status;
    final s = (status ?? '').toString().toLowerCase();
    return s == 'on' || s == 'true' || s == '1';
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF7F7FB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Device Maintenance',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ترتيب حسب آخر صيانة
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _devicesRef
            .orderBy('lastMaintenanceAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return const Center(child: Text('Something went wrong'));
          }

          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No devices found'));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingTextStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF32345F),
                        fontSize: 13,
                      ),
                      dataTextStyle: const TextStyle(
                        fontSize: 12.5,
                      ),
                      columns: const [
                        DataColumn(label: Text('Device Name')),
                        DataColumn(label: Text('Device ID')),
                        DataColumn(label: Text('Location')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Last Maintenance')),
                        DataColumn(label: Text('Maintenance Type')),
                      ],
                      rows: docs.map((d) {
                        final data = d.data();

                        final name = (data['name'] ?? '-').toString();
                        final deviceId = d.id;
                        final location = (data['location'] ?? '-').toString();
                        final status = data['status'];
                        final lastMaintAt = data['lastMaintenanceAt'];
                        final lastMaintType =
                            (data['lastMaintenanceType'] ?? '-').toString();

                        final isOn = _isOn(status);

                        return DataRow(
                          cells: [
                            DataCell(Text(name)),
                            DataCell(Text(deviceId)),
                            DataCell(Text(location)),
                            DataCell(_StatusChip(isOn: isOn)),
                            DataCell(Text(_formatTimestamp(lastMaintAt))),
                            DataCell(Text(lastMaintType)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isOn;

  const _StatusChip({required this.isOn});

  @override
  Widget build(BuildContext context) {
    final bg = isOn ? const Color(0xFFE7F7EC) : const Color(0xFFFFE8EA);
    final fg = isOn ? const Color(0xFF1B7A3A) : const Color(0xFFB0232E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isOn ? 'ON' : 'OFF',
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}