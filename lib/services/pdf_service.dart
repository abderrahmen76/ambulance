import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart' show Printing;
import '../models/mission_model.dart';

class PdfService {
  /// Generate and download mission report PDF
  static Future<void> generateMissionReportPdf(Mission mission) async {
    try {
      debugPrint('[PdfService] Generating PDF for mission: ${mission.missionNumber}');

      final pdf = pw.Document();

      // Get parsed data (already parsed from JSON in Mission model)
      final medicalHistory = mission.medicalHistory ?? [];
      final vitalSigns = mission.vitalSigns ?? {};
      final patientNeeds = mission.patientNeeds ?? [];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          header: (context) => _buildHeader(mission),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            pw.SizedBox(height: 10),
            if (mission.reportType != 'deceased') ...[
              _buildMissionSection(mission),
              pw.SizedBox(height: 15),
            ],
            _buildPatientSection(mission),
            pw.SizedBox(height: 15),
            if (mission.reportType == 'deceased') ...[
              _buildDeceasedSection(mission),
              pw.SizedBox(height: 15),
            ],
            if (mission.reportType != 'deceased') ...[
              _buildLocationsSection(mission),
              pw.SizedBox(height: 15),
              if (mission.reportType != null && mission.reportType!.isNotEmpty)
                _buildTechnicalSheetSection(mission, medicalHistory, vitalSigns, patientNeeds),
              pw.SizedBox(height: 15),
              _buildPaymentSection(mission),
            ],
          ],
        ),
      );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();
      debugPrint('[PdfService] PDF generated (${pdfBytes.length} bytes)');

      // Try to share/print the PDF with multiple fallback strategies
      bool pdfShared = false;

      // Strategy 1: Try sharePdf
      try {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Mission_${mission.missionNumber}.pdf',
        );
        debugPrint('[PdfService] PDF shared successfully with sharePdf');
        pdfShared = true;
      } catch (shareError) {
        debugPrint('[PdfService] sharePdf failed: $shareError');
      }

      // Strategy 2: If sharePdf failed, try layoutPdf
      if (!pdfShared) {
        try {
          await Printing.layoutPdf(
            onLayout: (PdfPageFormat format) async => pdfBytes,
            name: 'Mission_${mission.missionNumber}.pdf',
          );
          debugPrint('[PdfService] PDF opened with layoutPdf');
          pdfShared = true;
        } catch (layoutError) {
          debugPrint('[PdfService] layoutPdf failed: $layoutError');
        }
      }

      // Strategy 3: If both printing strategies failed, save to device
      if (!pdfShared) {
        try {
          final directory = await getApplicationDocumentsDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final filename = 'Mission_${mission.missionNumber}_$timestamp.pdf';
          final file = File('${directory.path}/$filename');
          
          await file.writeAsBytes(pdfBytes);
          debugPrint('[PdfService] PDF saved to device: ${file.path}');
          
          // Try to open the file
          if (Platform.isAndroid || Platform.isIOS) {
            // For mobile, we just save it. User can find it in their Files app
            await Printing.sharePdf(
              bytes: pdfBytes,
              filename: filename,
            );
          }
          pdfShared = true;
        } catch (fileError) {
          debugPrint('[PdfService] File save failed: $fileError');
        }
      }

      // If all strategies failed, throw error with helpful message
      if (!pdfShared) {
        throw Exception(
          'Could not generate PDF: Printing plugin not initialized. '
          'Please run: flutter clean && flutter pub get && flutter run'
        );
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
            'RAPPORT DE MISSION',
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
        'Page ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
      ),
    );
  }

  static pw.Widget _buildMissionSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('DETAILS DE MISSION'),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow('Numéro', mission.missionNumber),
            ),
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow('Date', mission.missionDate),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        _buildInfoRow('Statut', mission.status.toUpperCase()),
        pw.SizedBox(height: 6),
        _buildInfoRow('Conducteur', mission.driverName ?? 'Non assigné'),
        pw.SizedBox(height: 6),
        _buildInfoRow('Infirmier', mission.infirmierName ?? 'Non assigné'),
      ],
    );
  }

  static pw.Widget _buildPatientSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('INFO PATIENT'),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 2,
              child: _buildInfoRow(
                'Nom',
                '${mission.patientFirstName ?? ''} ${mission.patientLastName ?? ''}',
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow('Âge', mission.patientAge ?? 'N/A'),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        _buildInfoRow('Téléphone', mission.patientPhone ?? 'N/A'),
      ],
    );
  }

  static pw.Widget _buildDeceasedSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('RAPPORT'),
        pw.SizedBox(height: 8),
        _buildInfoRow('Statut', 'Décédé'),
      ],
    );
  }

  static pw.Widget _buildLocationsSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('TRAJET'),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'DE: ',
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
              'VERS: ',
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
    List<String> patientNeeds,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('DONNEES CLINIQUES'),
        pw.SizedBox(height: 8),
        _buildInfoRow('Type de Rapport', mission.reportType ?? 'N/A'),
        pw.SizedBox(height: 6),
        _buildInfoRow('Raison du Transport', mission.fracturesInjuries ?? 'N/A'),
        pw.SizedBox(height: 12),
        if (medicalHistory.isNotEmpty) ...[
          pw.Text(
            'Antécédents Médicaux:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: medicalHistory.map((item) {
              return pw.Text(
                '* ${_formatMedicalHistoryLabel(item)}',
                style: const pw.TextStyle(fontSize: 10),
              );
            }).toList(),
          ),
          pw.SizedBox(height: 8),
        ],
        if (vitalSigns.isNotEmpty) ...[
          pw.Text(
            'Signes Vitaux:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 4),
          _buildVitalSignsTable(vitalSigns),
          pw.SizedBox(height: 8),
        ],
        if (patientNeeds.isNotEmpty) ...[
          pw.Text(
            'Besoins du Patient:',
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
    final vitalSignOrder = ['ta', 'fc', 'spo2', 'fr', 'temperature', 'glucose'];

    for (var key in vitalSignOrder) {
      if (vitalSigns.containsKey(key)) {
        final value = vitalSigns[key];
        final label = _formatVitalSignLabel(key);
        final displayValue = value != null && value.toString().isNotEmpty ? value.toString() : 'N/A';
        
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
                  displayValue,
                  style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    }

    if (rows.isEmpty) {
      return pw.Text('Aucun signe vital enregistré', style: const pw.TextStyle(fontSize: 9));
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  static pw.Widget _buildPatientNeedsText(List<String> patientNeeds) {
    if (patientNeeds.isEmpty) {
      return pw.Text('Aucun besoin enregistré', style: const pw.TextStyle(fontSize: 9));
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: patientNeeds
          .map((need) => pw.Text('* ${_formatNeedLabel(need)}', style: const pw.TextStyle(fontSize: 10)))
          .toList(),
    );
  }

  static pw.Widget _buildPaymentSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PAIEMENT'),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow(
                'Statut',
                mission.isPaid == true ? 'PAYE' : 'NON PAYE',
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: _buildInfoRow('Méthode', mission.paymentType ?? 'Aucun'),
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
      var decoded = jsonDecode(jsonString);
      
      // Handle double-encoded JSON strings
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
      
      if (decoded is List) {
        return List<String>.from(decoded.map((e) => e.toString()).toList());
      }
    } catch (e) {
      debugPrint('[PdfService] Error parsing JSON list: $e');
    }
    return [];
  }

  static Map<String, dynamic> _parseJsonMap(String? jsonString) {
    if (jsonString == null || jsonString.isEmpty) return {};
    try {
      var decoded = jsonDecode(jsonString);
      
      // Handle double-encoded JSON strings
      if (decoded is String) {
        decoded = jsonDecode(decoded);
      }
      
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint('[PdfService] Error parsing JSON map: $e');
    }
    return {};
  }

  static String _formatVitalSignLabel(String key) {
    const labels = {
      'ta': 'TA (mmHg)',
      'fc': 'FC (bpm)',
      'spo2': 'SpO2 (%)',
      'fr': 'FR (br/min)',
      'temperature': 'Temp (C)',
      'glucose': 'Glucose (mg/dl)',
    };
    return labels[key] ?? key;
  }

  static String _formatNeedLabel(String key) {
    const labels = {
      'oxygen': 'Oxygène',
      'perfusion': 'Ligne IV',
      'monitorage': 'Monitorage',
      'pensement': 'Pansement',
      'immobilisation': 'Immobilisation',
    };
    return labels[key] ?? key;
  }

  static String _formatMedicalHistoryLabel(String key) {
    const labels = {
      'diabetic': 'Diabétique',
      'hta': 'Hypertension',
      'douleur_thorasique': 'Douleur Thoracique',
      'dialysis': 'Dialyse',
      'distresse_respiratoire': 'Détresse Respiratoire',
      'hypalepsie': 'Hypotension',
      'coronaria': 'Maladie Coronarienne',
    };
    return labels[key] ?? key;
  }
}
