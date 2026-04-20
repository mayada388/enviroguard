import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';

class AdminDeviceMaintenancePage extends StatelessWidget {
  const AdminDeviceMaintenancePage({super.key});

  Stream<List<Map<String, dynamic>>> _getAllDevices() {
    final sensorsStream =
        FirebaseFirestore.instance.collection('sensors').snapshots();

    final edgesStream =
        FirebaseFirestore.instance.collection('edge_devices').snapshots();

    return Rx.combineLatest2(
      sensorsStream,
      edgesStream,
      (QuerySnapshot sensorsSnap, QuerySnapshot edgesSnap) {
        final sensors = sensorsSnap.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return {
            'id': d.id,
            'type': 'sensor',
            ...data,
          };
        });

        final edges = edgesSnap.docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return {
            'id': d.id,
            'type': 'edge',
            ...data,
          };
        });

        return [...sensors, ...edges];
      },
    );
  }

  String _formatTime(dynamic value) {
    if (value == null) return '- -';

    DateTime? dt;
    if (value is Timestamp) dt = value.toDate();
    if (value is DateTime) dt = value;

    if (dt == null) return '- -';

    return '${dt.year}-${dt.month}-${dt.day}  ${dt.hour}:${dt.minute}';
  }

  bool _isOn(dynamic status) {
    final s = status?.toString().toLowerCase();
    return s == 'on' || s == 'true' || s == '1';
  }

  @override
  Widget build(BuildContext context) {
    const backgroundColor = Color(0xFFF7F7FB);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Device Maintenance',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
      ),

      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getAllDevices(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final devices = snap.data!;
          final isEmpty = devices.isEmpty;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 18,
                  headingRowColor:
                      MaterialStateProperty.all(const Color(0xFFE3F0FF)),
                  columns: const [
                    DataColumn(label: Text('Device ID')),
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Location')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Last Update / Seen')),
                  ],
                  rows: isEmpty
                      ? [
                          const DataRow(cells: [
                            DataCell(Text('-')),
                            DataCell(Text('-')),
                            DataCell(Text('-')),
                            DataCell(Text('-')),
                            DataCell(Text('-')),
                          ])
                        ]
                      : devices.map((d) {
                          final id = d['id'] ?? '-';
                          final type = d['type'] ?? '-';
                          final location = d['locationId'] ?? '-';
                          final status = _isOn(d['status']);
                          final time = d['lastUpdate'] ?? d['lastSeen'];

                          return DataRow(
                            cells: [
                              DataCell(Text(id)),
                              DataCell(Text(type)),
                              DataCell(Text(location)),
                              DataCell(
                                Text(status ? 'ON' : 'OFF'),
                              ),
                              DataCell(Text(_formatTime(time))),
                            ],
                          );
                        }).toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}