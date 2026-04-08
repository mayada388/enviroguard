import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart';

class ReportService {
  static Future<void> downloadAirQualityReport({
    required String locationId,
    required String locationName,
    required BuildContext context,
  }) async {
    try {
      // قراءة بيانات Firestore
      final aqDoc = await FirebaseFirestore.instance
          .collection('air_quality_data')
          .doc(locationId)
          .get();

      if (!aqDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No air quality data available')),
        );
        return;
      }

      final predDoc = await FirebaseFirestore.instance
          .collection('predictions')
          .doc(locationId)
          .get();

      final aq = aqDoc.data() ?? {};
      final pred = predDoc.data() ?? {};

      // تجهيز القيم
      final aqi = _asNum(aq['aqi']) ?? 0;
      final mainPollutant = (aq['mainPollutant'] ?? '--').toString();

      final updateTs = aq['updateTime'];
      DateTime? updatedAt;
      if (updateTs is Timestamp) updatedAt = updateTs.toDate();

      final met = (aq['met'] is Map<String, dynamic>)
          ? aq['met'] as Map<String, dynamic>
          : <String, dynamic>{};

      final pollutants = (aq['pollutants'] is Map<String, dynamic>)
          ? aq['pollutants'] as Map<String, dynamic>
          : <String, dynamic>{};
final pm25Forecast = (pred['PM2_5Forecast'] is List)
    ? (pred['PM2_5Forecast'] as List).cast<dynamic>()
    : <dynamic>[];

final pm10Forecast = (pred['PM10Forecast'] is List)
    ? (pred['PM10Forecast'] as List).cast<dynamic>()
    : <dynamic>[];

final co2Forecast = (pred['CO2Forecast'] is List)
    ? (pred['CO2Forecast'] as List).cast<dynamic>()
    : <dynamic>[];

      // إنشاء PDF
      final pdf = pw.Document();

      final generatedAt = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd – HH:mm').format(generatedAt);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (pw.Context ctx) {
            return [
              _header(locationName: locationName, generatedAt: dateStr),
              pw.SizedBox(height: 14),

              _sectionTitle('Air Quality Summary'),
              pw.SizedBox(height: 8),
              _kvTable({
                'AQI': aqi.toString(),
                'Main Pollutant': mainPollutant,
                'Updated At': updatedAt == null
                    ? '--'
                    : DateFormat('yyyy-MM-dd – HH:mm').format(updatedAt),
              }),

              pw.SizedBox(height: 16),
              _sectionTitle('Metrological Data'),
              pw.SizedBox(height: 8),
              _kvTable({
                'Pressure (hpa)': (met['pressure'] ?? '--').toString(),
                'Temperature (°C)': (met['temperature'] ?? '--').toString(),
                'Wind Speed (km/h)': (met['windSpeed'] ?? '--').toString(),
                'Humidity': (met['humidity'] ?? '--').toString(),
              }),

              pw.SizedBox(height: 16),
              _sectionTitle('Air Pollutants'),
              pw.SizedBox(height: 8),
              _pollutantsTable(pollutants),

              pw.SizedBox(height: 16),

              _sectionTitle('Forecasts'),
pw.SizedBox(height: 8),
_forecastTable(title: 'PM2.5 Forecast', list: pm25Forecast),
pw.SizedBox(height: 10),
_forecastTable(title: 'PM10 Forecast', list: pm10Forecast),
pw.SizedBox(height: 10),
_forecastTable(title: 'CO₂ Forecast', list: co2Forecast),

              pw.SizedBox(height: 18),
              pw.Divider(),
              pw.Text(
                'Generated automatically from system data.',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
            ];
          },
        ),
      );

      // حفظ الملف
      final dir = await getApplicationDocumentsDirectory();

      final safeName = sanitizeFileName(
        'Air_Quality_Report_${locationName}_${DateFormat('yyyyMMdd_HHmm').format(generatedAt)}.pdf',
      );

      final file = File('${dir.path}/$safeName');
      await file.writeAsBytes(await pdf.save());

      // فتح الملف
      await OpenFilex.open(file.path);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    }
  }

  // PDF Widgets 

  static pw.Widget _header({
    required String locationName,
    required String generatedAt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(10),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Air Quality Report',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text('Location: $locationName'),
            ],
          ),
          pw.Text(
            'Generated: $generatedAt',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
    );
  }

  static pw.Widget _kvTable(Map<String, String> data) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      children: data.entries.map((e) {
        return pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(e.key,
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(6),
              child: pw.Text(e.value),
            ),
          ],
        );
      }).toList(),
    );
  }

  static pw.Widget _pollutantsTable(Map<String, dynamic> pollutants) {
    Map<String, dynamic>? asMap(dynamic x) =>
        (x is Map<String, dynamic>) ? x : null;

    List<List<String>> rows = [];

    void add(String key, String label) {
      final m = asMap(pollutants[key]);
      final value = (m?['value'] ?? '--').toString();
      final level = (m?['level'] ?? '--').toString();
      rows.add([label, value, level]);
    }

    add('pm25', 'PM2.5');
add('pm10', 'PM10');
add('CO₂', 'CO₂');

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [_th('Pollutant'), _th('Value'), _th('Level')],
        ),
        ...rows.map((r) => pw.TableRow(
              children: [_td(r[0]), _td(r[1]), _td(r[2])],
            )),
      ],
    );
  }

  static pw.Widget _forecastTable({
    required String title,
    required List<dynamic> list,
  }) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [_th('Time'), _th('Value'), _th('Level')],
      )
    ];

    for (final item in list.take(8)) {
      final m = (item is Map<String, dynamic>) ? item : {};
      final ts = m['time'];
      DateTime? dt;
      if (ts is Timestamp) dt = ts.toDate();

      final timeStr = dt == null ? '--' : DateFormat('HH:mm').format(dt);
      final valueStr = (m['value'] ?? '--').toString();
      final levelStr = (m['level'] ?? '--').toString();

      rows.add(pw.TableRow(
        children: [_td(timeStr), _td(valueStr), _td(levelStr)],
      ));
    }

    if (rows.length == 1) {
      rows.add(pw.TableRow(children: [_td('--'), _td('--'), _td('--')]));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
          children: rows,
        ),
      ],
    );
  }

  static pw.Widget _th(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _td(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text),
      );

  static num? _asNum(dynamic v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }

  static String sanitizeFileName(String s) {
    return s.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
  }
}