import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printing;
import '../models/mission_model.dart';

class PdfService {
  /// Generate and download mission report PDF
  static Future<void> generateMissionReportPdf(Mission mission) async {
    try {
      debugPrint(
          '[PdfService] Generating PDF for mission: ${mission.missionNumber}');

      final pdf = pw.Document();

      // Parse nested JSON data
      final medicalHistory = _parseJsonList(mission.medicalHistory);
      final vitalSigns = _parseJsonMap(mission.vitalSigns);
      final patientNeeds = _parseJsonMap(mission.patientNeeds);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          header: (context) => _buildHeader(mission),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            pw.SizedBox(height: 10),
            _buildMissionSection(mission),
            pw.SizedBox(height: 15),
            _buildPatientSection(mission),
            pw.SizedBox(height: 15),
            _buildLocationsSection(mission),
            pw.SizedBox(height: 15),
            if (mission.reportType != null && mission.reportType!.isNotEmpty)
              _buildTechnicalSheetSection(
                  mission, medicalHistory, vitalSigns, patientNeeds),
            pw.SizedBox(height: 15),
            _buildPaymentSection(mission),
          ],
        ),
      );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();
      debugPrint('[PdfService] PDF generated (${pdfBytes.length} bytes)');

      // Try to share/print the PDF
      try {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Mission_${mission.missionNumber}.pdf',
        );
        debugPrint('[PdfService] PDF shared successfully');
      } catch (printingError) {
        debugPrint('[PdfService] Printing error: $printingError');
        // Fallback: Try layoutPdf
        try {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes,
            name: 'Mission_${mission.missionNumber}.pdf',
          );
          debugPrint('[PdfService] PDF opened with layoutPdf');
        } catch (layoutError) {
          debugPrint('[PdfService] LayoutPdf also failed: $layoutError');
          rethrow;
        }
      }
    } catch (e) {
      debugPrint('[PdfService] ERROR generating PDF: $e');
      rethrow;
    }
  }

  static pw.Widget _buildHeader(Mission mission) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 2, color: PdfColors.red),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'MISSION REPORT',
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.red,
            ),
          ),
          pw.Text(
            'Mission #${mission.missionNumber}',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 1, color: PdfColors.grey),
        ),
      ),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  static pw.Widget _buildMissionSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MISSION DETAILS'),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow('Number', mission.missionNumber),
            ),
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow('Date', mission.missionDate),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow('Priority', mission.priority.toUpperCase()),
            ),
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow('Status', mission.status.toUpperCase()),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        _buildInfoRow('Driver', mission.driverName ?? 'Not assigned'),
        pw.SizedBox(height: 6),
        _buildInfoRow('Nurse', mission.infirmierName ?? 'Not assigned'),
      ],
    );
  }

  static pw.Widget _buildPatientSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PATIENT INFO'),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 2,
              child: _buildInfoRow(
                'Name',
                '${mission.patientFirstName ?? ''} ${mission.patientLastName ?? ''}',
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow('Age', mission.patientAge ?? 'N/A'),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        _buildInfoRow('Phone', mission.patientPhone ?? 'N/A'),
      ],
    );
  }

  static pw.Widget _buildLocationsSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('ROUTE'),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'FROM: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.Expanded(
              child: pw.Text(
                mission.fromLocation,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'TO: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            ),
            pw.Expanded(
              child: pw.Text(
                mission.toLocation,
                style: const pw.TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildTechnicalSheetSection(
    Mission mission,
    List<String> medicalHistory,
    Map<String, dynamic> vitalSigns,
    Map<String, dynamic> patientNeeds,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('CLINICAL DATA'),
        pw.SizedBox(height: 8),
        _buildInfoRow('Report Type', mission.reportType ?? 'N/A'),
        pw.SizedBox(height: 6),
        _buildInfoRow('Transport Reason', mission.fracturesInjuries ?? 'N/A'),
        pw.SizedBox(height: 12),
        if (medicalHistory.isNotEmpty) ...[
          pw.Text(
            'Medical History:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            medicalHistory.join(', '),
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
        ],
        if (vitalSigns.isNotEmpty) ...[
          pw.Text(
            'Vital Signs:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          _buildVitalSignsTable(vitalSigns),
          pw.SizedBox(height: 8),
        ],
        if (patientNeeds.isNotEmpty) ...[
          pw.Text(
            'Patient Needs:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          _buildPatientNeedsText(patientNeeds),
        ],
      ],
    );
  }

  static pw.Widget _buildVitalSignsTable(Map<String, dynamic> vitalSigns) {
    final rows = <pw.TableRow>[];

    vitalSigns.forEach((key, value) {
      if (value != null && value.toString().isNotEmpty) {
        final label = _formatVitalSignLabel(key);
        rows.add(
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  value.toString(),
                  style: const pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    });

    if (rows.isEmpty) {
      return pw.Text('No vital signs recorded',
          style: const pw.TextStyle(fontSize: 9));
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  static pw.Widget _buildPatientNeedsText(Map<String, dynamic> patientNeeds) {
    final needs = <String>[];

    patientNeeds.forEach((key, value) {
      if (value != null) {
        if (value is Map) {
          if (key == 'perfusion' && value['quantity'] != null) {
            needs.add('IV: ${value['quantity']} (${value['type'] ?? 'N/A'})');
          }
        } else if (value is String && value.isNotEmpty) {
          needs.add('${_formatNeedLabel(key)}: $value');
        } else if (value is bool && value) {
          needs.add(_formatNeedLabel(key));
        }
      }
    });

    if (needs.isEmpty) {
      return pw.Text('No needs recorded',
          style: const pw.TextStyle(fontSize: 9));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: needs
          .map((need) =>
              pw.Text('* $need', style: const pw.TextStyle(fontSize: 10)))
          .toList(),
    );
  }

  static pw.Widget _buildPaymentSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PAYMENT'),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow(
                'Status',
                mission.isPaid == true ? 'PAID' : 'NOT PAID',
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow('Method', mission.paymentType ?? 'None'),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border(
          left: pw.BorderSide(width: 3, color: PdfColors.red),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 12,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 60,
          child: pw.Text(
            '$label:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  static List<String> _parseJsonList(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is List) {
        return List<String>.from(decoded);
      }
      if (decoded is String) {
        final innerDecoded = jsonDecode(decoded);
        if (innerDecoded is List) {
          return List<String>.from(innerDecoded);
        }
      }
    } catch (e) {
      debugPrint('[PdfService] Error parsing JSON list: $e');
    }
    return [];
  }

  static Map<String, dynamic> _parseJsonMap(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return {};
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is String) {
        final innerDecoded = jsonDecode(decoded);
        if (innerDecoded is Map) {
          return Map<String, dynamic>.from(innerDecoded);
        }
      }
    } catch (e) {
      debugPrint('[PdfService] Error parsing JSON map: $e');
    }
    return {};
  }

  static String _formatVitalSignLabel(String key) {
    const labels = {
      'ta': 'BP (mmHg)',
      'fc': 'HR (bpm)',
      'spo2': 'SpO2 (%)',
      'fr': 'RR (br/min)',
      'temperature': 'Temp (C)',
      'glucose': 'Glucose (mg/dl)',
    };
    return labels[key] ?? key;
  }

  static String _formatNeedLabel(String key) {
    const labels = {
      'oxygen': 'Oxygen',
      'perfusion': 'IV Line',
      'monitorage': 'Monitoring',
      'pensement': 'Dressing',
      'immobilisation': 'Immobilization',
    };
    return labels[key] ?? key;
  }
}
