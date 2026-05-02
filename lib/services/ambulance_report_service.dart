import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/ambulance_model.dart';
import '../models/fuel_card_model.dart';
import '../models/maintenance_record_model.dart';
import '../models/mission_model.dart';

class AmbulanceReportService {
  Future<void> generateAndDownloadReport({
    required Ambulance ambulance,
    required List<FuelCard> fuelCards,
    required List<MaintenanceRecord> maintenanceRecords,
    required List<Mission> missions,
    required int availableCount,
    required int inServiceCount,
    required int maintenanceCount,
  }) async {
    final pdf = pw.Document();

    // Calculate statistics
    final completedMissions = missions
        .where((m) => m.ambulanceId == ambulance.id && m.status == 'completed')
        .length;
    final totalMissionsCount =
        missions.where((m) => m.ambulanceId == ambulance.id).length;
    final accomplishmentRate =
        totalMissionsCount > 0 ? (completedMissions / totalMissionsCount) : 0.0;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(width: 2, color: PdfColors.blue700)),
            ),
            padding: const pw.EdgeInsets.only(bottom: 20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'RAPPORT AMBULANCE',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue700,
                          ),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Text(
                          ambulance.ambulanceNumber,
                          style: const pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Téléphone: ${ambulance.telephone ?? 'N/A'}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Généré le: ${DateTime.now().toString().split(' ')[0]}',
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 30),

          // Fleet Statistics Summary
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            padding: const pw.EdgeInsets.all(15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'STATISTIQUES DE LA FLOTTE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard('DISPONIBLE', availableCount.toString(),
                        PdfColors.green),
                    _buildStatCard('EN SERVICE', inServiceCount.toString(),
                        PdfColors.orange),
                    _buildStatCard('MAINTENANCE', maintenanceCount.toString(),
                        PdfColors.red),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 25),

          // Accomplishment Rate
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 1),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            padding: const pw.EdgeInsets.all(15),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'TAUX D\'ACCOMPLISSEMENT DES MISSIONS',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue700,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Missions Complétées: $completedMissions / $totalMissionsCount',
                          style: const pw.TextStyle(fontSize: 11),
                        ),
                        pw.SizedBox(height: 8),
                        pw.Container(
                          width: 250,
                          height: 20,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey300),
                            borderRadius: const pw.BorderRadius.all(
                                pw.Radius.circular(4)),
                          ),
                          child: pw.Row(
                            children: [
                              pw.Container(
                                width: 250 * accomplishmentRate,
                                height: 20,
                                decoration: pw.BoxDecoration(
                                  color: accomplishmentRate > 0.75
                                      ? PdfColors.green
                                      : accomplishmentRate > 0.5
                                          ? PdfColors.orange
                                          : PdfColors.red,
                                  borderRadius: const pw.BorderRadius.all(
                                      pw.Radius.circular(3)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          '${(accomplishmentRate * 100).toStringAsFixed(1)}%',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: accomplishmentRate > 0.75
                                ? PdfColors.green
                                : accomplishmentRate > 0.5
                                    ? PdfColors.orange
                                    : PdfColors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 25),

          // Fuel Cards Section
          if (fuelCards.isNotEmpty) ...[
            pw.Text(
              'CARTES CARBURANT',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue700,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.center,
              headerDecoration: pw.BoxDecoration(
                color: PdfColors.blue700,
              ),
              headers: [
                'Conducteur',
                'Soldes Payé (TND)',
                'Soldes Restant (TND)',
                'Date',
              ],
              data: fuelCards
                  .map((card) => [
                        card.driverName,
                        '${card.soldesPaid}',
                        '${card.soldesRestant}',
                        card.date ?? 'N/A',
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5,
              ),
            ),
            pw.SizedBox(height: 25),
          ],

          // Maintenance Records Section
          if (maintenanceRecords.isNotEmpty) ...[
            pw.Text(
              'HISTORIQUE D\'ENTRETIEN',
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue700,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              context: context,
              cellAlignment: pw.Alignment.center,
              headerDecoration: pw.BoxDecoration(
                color: PdfColors.blue700,
              ),
              headers: [
                'Type',
                'Description',
                'Date',
                'Mécanicien',
              ],
              data: maintenanceRecords
                  .map((record) => [
                        record.maintenanceType.toUpperCase(),
                        record.maintenanceDescription,
                        record.date,
                        record.mechanicName ?? 'N/A',
                      ])
                  .toList(),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5,
              ),
            ),
            pw.SizedBox(height: 25),
          ],

          // Footer
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 10),
          pw.Text(
            'Rapport généré automatiquement par le système de gestion des ambulances',
            style: const pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey,
            ),
          ),
        ],
      ),
    );

    // Print and save the PDF
    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename:
          'Rapport_${ambulance.ambulanceNumber}_${DateTime.now().toString().split(' ')[0]}.pdf',
    );
  }

  pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 80,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 2),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      padding: const pw.EdgeInsets.all(10),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            label,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
