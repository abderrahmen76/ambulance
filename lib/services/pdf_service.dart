import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
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
      final documentFont = await _loadDocumentFont();

      // Get parsed data (already parsed from JSON in Mission model)
      final medicalHistory = mission.medicalHistory ?? [];
      final vitalSigns = mission.vitalSigns ?? {};
      final patientNeeds = mission.patientNeeds ?? {};
      final medications = mission.medications ?? <Map<String, dynamic>>[];

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(9),
          theme: pw.ThemeData.withFont(
            base: documentFont,
            bold: documentFont,
          ),
          header: (context) => _buildHeader(mission),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            pw.SizedBox(height: 1),
            if (mission.reportType != 'deceased') ...[
              _buildMissionSection(mission),
              pw.SizedBox(height: 2),
            ],
            _buildPatientSection(mission),
            pw.SizedBox(height: 2),
            if (mission.reportType == 'deceased') ...[
              _buildDeceasedSection(mission),
              pw.SizedBox(height: 2),
            ],
            if (mission.reportType != 'deceased') ...[
              _buildLocationsSection(mission),
              pw.SizedBox(height: 2),
              if ((mission.reportType != null && mission.reportType!.isNotEmpty) ||
                  medicalHistory.isNotEmpty ||
                  vitalSigns.isNotEmpty ||
                  patientNeeds.isNotEmpty ||
                  medications.isNotEmpty)
                _buildTechnicalSheetSection(
                    mission, medicalHistory, vitalSigns, patientNeeds, medications),
            ],
          ],
        ),
      );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();
      debugPrint('[PdfService] PDF generated (${pdfBytes.length} bytes)');

      // Try to share/print the PDF with multiple fallback strategies
      bool pdfShared = false;
      final exportTimestamp = DateTime.now().millisecondsSinceEpoch;

      // Strategy 1: Try sharePdf
      try {
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename: 'Mission_${mission.missionNumber}_${exportTimestamp}.pdf',
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
            name: 'Mission_${mission.missionNumber}_${exportTimestamp}.pdf',
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
            'Please run: flutter clean && flutter pub get && flutter run');
      }
    } catch (e) {
      debugPrint('[PdfService] ERROR generating PDF: $e');
      rethrow;
    }
  }

  static pw.Widget _buildHeader(Mission mission) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 1.5, color: PdfColors.red),
        ),
      ),
      child: pw.Text(
        'RAPPORT DE MISSION #${mission.missionNumber}',
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.red,
        ),
      ),
    );
  }

  static pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 1, color: PdfColors.grey),
        ),
      ),
      child: pw.Text(
        'Page ${context.pageNumber} de ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey),
      ),
    );
  }

  static pw.Widget _buildMissionSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('MISSION'),
        pw.SizedBox(height: 1),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 1,
              child: _buildTinyInfoRow('N°', mission.missionNumber),
            ),
            pw.Expanded(
              flex: 1,
              child: _buildTinyInfoRow('Date', mission.missionDate),
            ),
            pw.Expanded(
              flex: 1,
              child: _buildTinyInfoRow('Chef', mission.driverName ?? 'N/A'),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPatientSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PATIENT'),
        pw.SizedBox(height: 1),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 2,
              child: _buildTinyInfoRow(
                'Nom',
                (mission.patientName?.isNotEmpty ?? false)
                    ? mission.patientName!
                    : ((mission.patientFirstName?.isEmpty ?? true) &&
                            (mission.patientLastName?.isEmpty ?? true))
                        ? 'N/A'
                        : '${mission.patientFirstName ?? ''} ${mission.patientLastName ?? ''}'
                            .trim(),
              ),
            ),
            pw.Expanded(
              flex: 1,
              child: _buildTinyInfoRow('Age', mission.patientAge ?? 'N/A'),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildDeceasedSection(Mission mission) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('RAPPORT'),
        pw.SizedBox(height: 8),
        _buildInfoRow('Statut', 'Decede'),
      ],
    );
  }

  static pw.Widget _buildLocationsSection(Mission mission) {
    final routeFrom = _resolveLocationText(
      primary: mission.pickupAddress,
      fallback: mission.fromLocation,
    );
    final routeTo = _resolveLocationText(
      primary: mission.destinationAddress,
      fallback: mission.toLocation,
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('TRAJET'),
        pw.SizedBox(height: 2),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 40,
              child: pw.Text(
                'DE:',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                _preparePdfText(routeFrom),
                style: const pw.TextStyle(fontSize: 8.5),
                textAlign:
                    _containsArabic(routeFrom) ? pw.TextAlign.right : pw.TextAlign.left,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 1),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 40,
              child: pw.Text(
                'VERS:',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                _preparePdfText(routeTo),
                style: const pw.TextStyle(fontSize: 8.5),
                textAlign:
                    _containsArabic(routeTo) ? pw.TextAlign.right : pw.TextAlign.left,
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
    List<Map<String, dynamic>> medications,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('DONNEES CLINIQUES'),
        pw.SizedBox(height: 3),
        pw.Row(
          children: [
            pw.Expanded(
              flex: 1,
              child: _buildTinyInfoRow('Type', mission.reportType ?? 'N/A'),
            ),
            pw.Expanded(
              flex: 1,
              child: _buildTinyInfoRow(
                  'Raison', mission.fracturesInjuries ?? 'N/A'),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        // 3-Column clinical data layout
        pw.Table(
          border: pw.TableBorder.all(
            color: PdfColors.grey300,
            width: 0.5,
          ),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text(
                    'ANTECEDENTS',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text('SIGNES VITAUX',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: pw.Text('BESOINS',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                          fontSize: 9, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: medicalHistory.isNotEmpty
                      ? pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: medicalHistory.map((item) {
                            return pw.Text(
                              _preparePdfText(_formatMedicalHistoryLabel(item)),
                              style: const pw.TextStyle(fontSize: 8.5),
                              textAlign: _containsArabic(item)
                                  ? pw.TextAlign.right
                                  : pw.TextAlign.left,
                            );
                          }).toList(),
                        )
                      : pw.Text('N/A',
                          style: const pw.TextStyle(fontSize: 8.5)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: vitalSigns.isNotEmpty
                      ? _buildVitalSignsCompactInline(vitalSigns)
                      : pw.Text('N/A',
                          style: const pw.TextStyle(fontSize: 8.5)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(3),
                  child: patientNeeds.isNotEmpty
                      ? _buildPatientNeedsCompactInline(patientNeeds)
                      : pw.Text('N/A',
                          style: const pw.TextStyle(fontSize: 8.5)),
                ),
              ],
            ),
          ],
        ),
        if (medications.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          _buildMedicationsSection(medications),
        ],
      ],
    );
  }

  static pw.Widget _buildMedicationsSection(
    List<Map<String, dynamic>> medications,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColors.grey300,
        width: 0.5,
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableHeaderCell('MEDICAMENT'),
            _buildTableHeaderCell('DOSAGE'),
            _buildTableHeaderCell('FREQUENCE'),
          ],
        ),
        ...medications.map((medication) {
          return pw.TableRow(
            children: [
              _buildTableValueCell(medication['name']?.toString() ?? 'N/A'),
              _buildTableValueCell(medication['dosage']?.toString() ?? 'N/A'),
              _buildTableValueCell(
                medication['frequency']?.toString() ?? 'N/A',
              ),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildVitalSignsCompactInline(
      Map<String, dynamic> vitalSigns) {
    final vitalSignPairs = [
      ['ta_before', 'ta_after', 'TA (mmHg)'],
      ['fc_before', 'fc_after', 'FC (bpm)'],
      ['fr_before', 'fr_after', 'FR (br/min)'],
      ['temperature_before', 'temperature_after', 'Temp (C)'],
      ['glucose_before', 'glucose_after', 'Glucose (mg/dl)'],
      ['spo2_before', 'spo2_after', 'SpO2 (%)'],
    ];
    final items = <pw.Widget>[];
    for (var pair in vitalSignPairs) {
      final beforeKey = pair[0];
      final afterKey = pair[1];
      final label = pair[2];
      final before = vitalSigns[beforeKey]?.toString().trim() ?? '';
      final after = vitalSigns[afterKey]?.toString().trim() ?? '';
      if ((before.isNotEmpty && before != '0') ||
          (after.isNotEmpty && after != '0')) {
        items.add(
          pw.Text(
            '$label: Avant: ${before.isNotEmpty && before != '0' ? before : 'N/A'} | Apres: ${after.isNotEmpty && after != '0' ? after : 'N/A'}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        );
      }
    }
    return items.isNotEmpty
        ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: items,
          )
        : pw.Text('N/A', style: const pw.TextStyle(fontSize: 9));
  }

  static pw.Widget _buildPatientNeedsCompactInline(
      Map<String, dynamic> patientNeeds) {
    if (patientNeeds.isEmpty) {
      return pw.Text('N/A', style: const pw.TextStyle(fontSize: 9));
    }

    debugPrint(
        '[PDF_OXYGEN_DEBUG] _buildPatientNeedsCompactInline - ALL KEYS: ${patientNeeds.keys.toList()}');
    patientNeeds.forEach((key, value) {
      debugPrint(
          '[PDF_OXYGEN_DEBUG] Processing: key=$key, valueType=${value.runtimeType}, value=$value');
    });

    final needsList = <pw.Widget>[];
    final categories = <String, List<MapEntry<String, dynamic>>>{};

    // Group needs by category
    patientNeeds.forEach((key, value) {
      final category = _getNeedCategory(key);
      categories.putIfAbsent(category, () => []);
      categories[category]!.add(MapEntry(key, value));
    });

    // Define category order
    const categoryOrder = ['VNI/VC', 'Vital Signs', 'Supplies', 'PSE', 'Other'];

    // Iterate through categories in order
    bool isFirstCategory = true;
    for (var category in categoryOrder) {
      if (categories.containsKey(category)) {
        // Add spacing before category (except for first)
        if (!isFirstCategory) {
          needsList.add(pw.SizedBox(height: 1.5));
        }

        // Add category header with separator
        needsList.add(pw.Container(
          margin: const pw.EdgeInsets.only(top: 1.5, bottom: 1.5),
          child: pw.Text(
            category,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
        ));

        // Add needs under this category
        for (var entry in categories[category]!) {
          final key = entry.key;
          final value = entry.value;

          if (value is String && value.isNotEmpty) {
            final label = _formatNeedLabel(key);
            final lowerKey = key.toLowerCase();
            final displayValue = (lowerKey == 'oxygen' ||
                    lowerKey == 'oxygene' ||
                    lowerKey == 'oxygene')
                ? '$value L'
                : value;
            debugPrint(
                '[PDF_OXYGEN_DEBUG] String - key=$key, value=$value, displayValue=$displayValue, isOxygen=${lowerKey == 'oxygen' || lowerKey == 'oxygene' || lowerKey == 'oxygene'}');
            needsList.add(pw.Padding(
              padding: const pw.EdgeInsets.only(left: 3),
              child: pw.Text('$label: $displayValue',
                  style: const pw.TextStyle(fontSize: 8.5)),
            ));
          } else if (value is int && value > 0) {
            final label = _formatNeedLabel(key);
            final lowerKey = key.toLowerCase();
            final displayValue = (lowerKey == 'oxygen' ||
                    lowerKey == 'oxygene' ||
                    lowerKey == 'oxygene')
                ? '$value L'
                : value.toString();
            debugPrint(
                '[PDF_OXYGEN_DEBUG] Int - key=$key, value=$value, displayValue=$displayValue, isOxygen=${lowerKey == 'oxygen' || lowerKey == 'oxygene' || lowerKey == 'oxygene'}');
            needsList.add(pw.Padding(
              padding: const pw.EdgeInsets.only(left: 3),
              child: pw.Text('$label: $displayValue',
                  style: const pw.TextStyle(fontSize: 8.5)),
            ));
          } else if (value is double && value > 0) {
            final label = _formatNeedLabel(key);
            final lowerKey = key.toLowerCase();
            final displayValue = (lowerKey == 'oxygen' ||
                    lowerKey == 'oxygene' ||
                    lowerKey == 'oxygene')
                ? '$value L'
                : value.toString();
            debugPrint(
                '[PDF_OXYGEN_DEBUG] Double - key=$key, value=$value, displayValue=$displayValue, isOxygen=${lowerKey == 'oxygen' || lowerKey == 'oxygene' || lowerKey == 'oxygene'}');
            needsList.add(pw.Padding(
              padding: const pw.EdgeInsets.only(left: 3),
              child: pw.Text('$label: $displayValue',
                  style: const pw.TextStyle(fontSize: 8.5)),
            ));
          } else if (value is Map<String, dynamic>) {
            final quantity = value['quantity']?.toString() ?? '';
            final type = value['type']?.toString() ?? '';
            final children = value['children'] as List? ?? [];

            if (children.isNotEmpty) {
              String displayText = _formatNeedLabel(key);
              if (quantity.isNotEmpty && quantity != '0') {
                displayText += ' ($quantity)';
              }
              needsList.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 3),
                child: pw.Text(displayText,
                    style: const pw.TextStyle(fontSize: 8.5)),
              ));

              for (var child in children) {
                if (child is Map<String, dynamic>) {
                  final childName = child['name']?.toString() ?? '';
                  final childQty = (child['vitesse'] ?? child['quantity'])?.toString() ?? ''; 
                  final childTime = child['time']?.toString() ?? '';

                  String childDisplay = '  $childName';
                  if (childQty.isNotEmpty && childQty != '0') {
                    childDisplay += ' ($childQty)';
                  }
                  if (childTime.isNotEmpty) {
                    childDisplay += ' en $childTime h';
                  }

                  needsList.add(pw.Padding(
                    padding: const pw.EdgeInsets.only(left: 3),
                    child: pw.Text(childDisplay,
                        style: const pw.TextStyle(fontSize: 8)),
                  ));
                }
              }
            } else if (type.isNotEmpty && quantity.isNotEmpty) {
              final lowerKey = key.toLowerCase();
              final suffix = (lowerKey == 'oxygen' ||
                      lowerKey == 'oxygene' ||
                      lowerKey == 'oxygene')
                  ? ' L'
                  : '';
              debugPrint(
                  '[PDF_OXYGEN_DEBUG] Map (type+qty) - key=$key, quantity=$quantity, type=$type, suffix=$suffix');
              needsList.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 3),
                child: pw.Text(
                    '${_formatNeedLabel(key)}: $quantity$suffix ($type)',
                    style: const pw.TextStyle(fontSize: 8.5)),
              ));
            } else if (quantity.isNotEmpty) {
              final lowerKey = key.toLowerCase();
              final suffix = (lowerKey == 'oxygen' ||
                      lowerKey == 'oxygene' ||
                      lowerKey == 'oxygene')
                  ? ' L'
                  : '';
              debugPrint(
                  '[PDF_OXYGEN_DEBUG] Map (qty only) - key=$key, quantity=$quantity, suffix=$suffix');
              needsList.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 3),
                child: pw.Text('${_formatNeedLabel(key)}: $quantity$suffix',
                    style: const pw.TextStyle(fontSize: 8.5)),
              ));
            } else if (type.isNotEmpty) {
              needsList.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 3),
                child: pw.Text('${_formatNeedLabel(key)}: $type',
                    style: const pw.TextStyle(fontSize: 8.5)),
              ));
            } else {
              // Display just the need name if no quantity or type (custom needs)
              needsList.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 3),
                child: pw.Text(_formatNeedLabel(key),
                    style: const pw.TextStyle(fontSize: 8.5)),
              ));
            }
          }
        }

        isFirstCategory = false;
      }
    }

    return needsList.isNotEmpty
        ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: needsList,
          )
        : pw.Text('N/A', style: const pw.TextStyle(fontSize: 9));
  }

  static pw.Widget _buildVitalSignsTableCompact(
      Map<String, dynamic> vitalSigns) {
    final rows = <pw.TableRow>[];
    final vitalSignOrder = [
      'ta',
      'fc',
      'spo2_before',
      'spo2_after',
      'fr',
      'temperature',
      'glucose'
    ];

    for (var key in vitalSignOrder) {
      if (vitalSigns.containsKey(key)) {
        final value = vitalSigns[key];
        final label = _formatVitalSignLabel(key);

        // Handle both string and other types
        String displayValue = 'N/A';
        if (value != null) {
          final stringValue = value.toString().trim();
          if (stringValue.isNotEmpty && stringValue != '0') {
            displayValue = stringValue;
          }
        }

        rows.add(
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text(label, style: const pw.TextStyle(fontSize: 8.5)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pw.Text(
                  displayValue,
                  style: pw.TextStyle(
                      fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    }

    if (rows.isEmpty) {
      return pw.Text('Aucun signe vital',
          style: const pw.TextStyle(fontSize: 9));
    }

    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2),
        1: const pw.FlexColumnWidth(0.8),
      },
      children: rows,
    );
  }

  static pw.Widget _buildPatientNeedsTextCompact(
      Map<String, dynamic> patientNeeds) {
    if (patientNeeds.isEmpty) {
      return pw.Text('Aucun besoin', style: const pw.TextStyle(fontSize: 9));
    }

    final needsList = <pw.Widget>[];

    patientNeeds.forEach((key, value) {
      if (value is String && value.isNotEmpty) {
        needsList.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text('- ${_formatNeedLabel(key)}: $value',
              style: const pw.TextStyle(fontSize: 9)),
        ));
      } else if (value is int) {
        needsList.add(pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 2),
          child: pw.Text('- ${_formatNeedLabel(key)}: $value',
              style: const pw.TextStyle(fontSize: 9)),
        ));
      } else if (value is Map<String, dynamic>) {
        final quantity = value['quantity']?.toString() ?? '';
        final type = value['type']?.toString() ?? '';
        final children = value['children'] as List? ?? [];

        if (children.isNotEmpty) {
          String displayText = '- ${_formatNeedLabel(key)}';
          if (quantity.isNotEmpty && quantity != '0') {
            displayText += ' ($quantity)';
          }
          needsList.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(displayText, style: const pw.TextStyle(fontSize: 9)),
          ));

          for (var child in children) {
            if (child is Map<String, dynamic>) {
              final childName = child['name']?.toString() ?? '';
              final childQty = (child['vitesse'] ?? child['quantity'])?.toString() ?? ''; 
              final childTime = child['time']?.toString() ?? '';

              String childDisplay = '  - $childName';
              if (childQty.isNotEmpty && childQty != '0') {
                childDisplay += ' ($childQty)';
              }
              if (childTime.isNotEmpty) {
                childDisplay += ' en $childTime heure';
              }

              needsList.add(pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 2),
                child: pw.Text(childDisplay,
                    style: const pw.TextStyle(fontSize: 8.5)),
              ));
            }
          }
        } else if (type.isNotEmpty && quantity.isNotEmpty) {
          final lowerKey = key.toLowerCase();
          final suffix = (lowerKey == 'oxygen' ||
                  lowerKey == 'oxygene' ||
                  lowerKey == 'oxygene')
              ? ' L'
              : '';
          needsList.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text(
                '- ${_formatNeedLabel(key)}: $quantity$suffix ($type)',
                style: const pw.TextStyle(fontSize: 9)),
          ));
        } else if (quantity.isNotEmpty) {
          final lowerKey = key.toLowerCase();
          final suffix = (lowerKey == 'oxygen' ||
                  lowerKey == 'oxygene' ||
                  lowerKey == 'oxygene')
              ? ' L'
              : '';
          needsList.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text('- ${_formatNeedLabel(key)}: $quantity$suffix',
                style: const pw.TextStyle(fontSize: 9)),
          ));
        } else if (type.isNotEmpty) {
          needsList.add(pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 2),
            child: pw.Text('- ${_formatNeedLabel(key)}: $type',
                style: const pw.TextStyle(fontSize: 9)),
          ));
        }
      }
    });

    return needsList.isNotEmpty
        ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: needsList,
          )
        : pw.Text('Aucun besoin', style: const pw.TextStyle(fontSize: 9));
  }

  static pw.Widget _buildVitalSignsTable(Map<String, dynamic> vitalSigns) {
    final rows = <pw.TableRow>[];
    final vitalSignOrder = [
      'ta',
      'fc',
      'spo2_before',
      'spo2_after',
      'fr',
      'temperature',
      'glucose'
    ];

    for (var key in vitalSignOrder) {
      if (vitalSigns.containsKey(key)) {
        final value = vitalSigns[key];
        final label = _formatVitalSignLabel(key);
        final displayValue = value != null && value.toString().isNotEmpty
            ? value.toString()
            : 'N/A';

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
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    }

    if (rows.isEmpty) {
      return pw.Text('Aucun signe vital enregistre',
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
    if (patientNeeds.isEmpty) {
      return pw.Text('Aucun besoin enregistre',
          style: const pw.TextStyle(fontSize: 9));
    }

    final needsList = <pw.Widget>[];

    patientNeeds.forEach((key, value) {
      if (value is String && value.isNotEmpty) {
        // Simple string value (quantity only)
        needsList.add(pw.Text('- ${_formatNeedLabel(key)}: $value',
            style: const pw.TextStyle(fontSize: 10)));
      } else if (value is int) {
        // Integer quantity
        needsList.add(pw.Text('- ${_formatNeedLabel(key)}: $value',
            style: const pw.TextStyle(fontSize: 10)));
      } else if (value is Map<String, dynamic>) {
        // VNI/VC format or PSE with nested data
        final quantity = value['quantity']?.toString() ?? '';
        final type = value['type']?.toString() ?? '';
        final children = value['children'] as List? ?? [];

        if (children.isNotEmpty) {
          // New format with children (VNI, VC, PSE)
          String displayText = '- ${_formatNeedLabel(key)}';
          if (quantity.isNotEmpty && quantity != '0') {
            displayText += ' ($quantity)';
          }
          displayText += ':';
          needsList.add(
              pw.Text(displayText, style: const pw.TextStyle(fontSize: 10)));

          // Add children with quantities and times
          for (var child in children) {
            if (child is Map<String, dynamic>) {
              final childName = child['name']?.toString() ?? '';
              final childQty = (child['vitesse'] ?? child['quantity'])?.toString() ?? ''; 
              final childTime = child['time']?.toString() ?? '';

              String childDisplay = '  - $childName';
              if (childQty.isNotEmpty && childQty != '0') {
                childDisplay += ' ($childQty)';
              }
              if (childTime.isNotEmpty) {
                childDisplay += ' en $childTime';
              }

              needsList.add(pw.Text(childDisplay,
                  style: const pw.TextStyle(fontSize: 9)));
            }
          }
        } else if (type.isNotEmpty && quantity.isNotEmpty) {
          // Old format with type only (backward compatibility)
          final lowerKey = key.toLowerCase();
          final suffix = (lowerKey == 'oxygen' ||
                  lowerKey == 'oxygene' ||
                  lowerKey == 'oxygene')
              ? ' L'
              : '';
          needsList.add(pw.Text(
              '- ${_formatNeedLabel(key)}: $quantity$suffix ($type)',
              style: const pw.TextStyle(fontSize: 10)));
        } else if (quantity.isNotEmpty) {
          // Just quantity
          final lowerKey = key.toLowerCase();
          final suffix = (lowerKey == 'oxygen' ||
                  lowerKey == 'oxygene' ||
                  lowerKey == 'oxygene')
              ? ' L'
              : '';
          needsList.add(pw.Text('- ${_formatNeedLabel(key)}: $quantity$suffix',
              style: const pw.TextStyle(fontSize: 10)));
        } else if (type.isNotEmpty) {
          // Just type
          needsList.add(pw.Text('- ${_formatNeedLabel(key)}: $type',
              style: const pw.TextStyle(fontSize: 10)));
        }
      }
    });

    return needsList.isNotEmpty
        ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: needsList,
          )
        : pw.Text('Aucun besoin enregistre',
            style: const pw.TextStyle(fontSize: 9));
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
              child: _buildInfoRow('Methode', mission.paymentType ?? 'Aucun'),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        border: pw.Border(
          left: pw.BorderSide(width: 3, color: PdfColors.red),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
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
            _preparePdfText(value),
            style: const pw.TextStyle(fontSize: 10),
            textAlign: _containsArabic(value) ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCompactInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(
            fontSize: 8.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            _preparePdfText(value),
            style: const pw.TextStyle(fontSize: 8.5),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: _containsArabic(value) ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTinyInfoRow(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            _preparePdfText(value),
            style: const pw.TextStyle(fontSize: 7.5),
            maxLines: 1,
            overflow: pw.TextOverflow.clip,
            textAlign: _containsArabic(value) ? pw.TextAlign.right : pw.TextAlign.left,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableHeaderCell(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        title,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _buildTableValueCell(String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(3),
      child: pw.Text(
        _preparePdfText(value),
        style: const pw.TextStyle(fontSize: 8.5),
        textAlign: _containsArabic(value) ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  static Future<pw.Font> _loadDocumentFont() async {
    final fontData = await rootBundle.load('assets/fonts/arial.ttf');
    return pw.Font.ttf(fontData);
  }

  static String _resolveLocationText({
    required String fallback,
    String? primary,
  }) {
    final preferred = primary?.trim();
    if (preferred != null && preferred.isNotEmpty) {
      return preferred;
    }
    return fallback.trim().isNotEmpty ? fallback : 'N/A';
  }

  static bool _containsArabic(String text) {
    for (final rune in text.runes) {
      if ((rune >= 0x0600 && rune <= 0x06FF) ||
          (rune >= 0x0750 && rune <= 0x077F) ||
          (rune >= 0x08A0 && rune <= 0x08FF)) {
        return true;
      }
    }
    return false;
  }

  static String _preparePdfText(String value) {
    if (!_containsArabic(value)) {
      return value;
    }
    return _shapeArabicText(value);
  }

  static String _shapeArabicText(String text) {
    final chars = text.split('');
    final shaped = <String>[];

    for (var index = 0; index < chars.length; index++) {
      final char = chars[index];

      if (char == 'Ù„' &&
          index + 1 < chars.length &&
          const {'Ø§', 'Ø£', 'Ø¥', 'Ø¢'}.contains(chars[index + 1])) {
        continue;
      }

      if (index > 0 &&
          chars[index - 1] == 'Ù„' &&
          const {'Ø§', 'Ø£', 'Ø¥', 'Ø¢'}.contains(char)) {
        final previousIndex = index - 2;
        final previousChar = previousIndex >= 0 ? chars[previousIndex] : null;
        final joinPrevious =
            previousChar != null &&
            _connectsToLeft(previousChar) &&
            _connectsFromRight('Ù„');
        shaped.add(joinPrevious ? '\uFEFC' : '\uFEFB');
        continue;
      }

      final forms = _arabicLetterForms[char];
      if (forms == null) {
        shaped.add(char);
        continue;
      }

      final previousChar = index > 0 ? chars[index - 1] : null;
      final nextChar = index + 1 < chars.length ? chars[index + 1] : null;
      final joinPrevious =
          previousChar != null &&
          _connectsToLeft(previousChar) &&
          _connectsFromRight(char);
      final joinNext =
          nextChar != null &&
          _connectsToLeft(char) &&
          _connectsFromRight(nextChar);

      final isolated = forms[0]!;
      final terminal = forms[1];
      final initial = forms[2];
      final medial = forms[3];

      if (joinPrevious && joinNext && medial != null) {
        shaped.add(medial);
      } else if (joinPrevious && terminal != null) {
        shaped.add(terminal);
      } else if (joinNext && initial != null) {
        shaped.add(initial);
      } else {
        shaped.add(isolated);
      }
    }

    return shaped.reversed.join();
  }

  static bool _connectsFromRight(String char) {
    final forms = _arabicLetterForms[char];
    return forms != null && forms[1] != null;
  }

  static bool _connectsToLeft(String char) {
    final forms = _arabicLetterForms[char];
    return forms != null && forms[2] != null;
  }

  static const Map<String, List<String?>> _arabicLetterForms = {
    'Ø¡': ['\uFE80', null, null, null],
    'Ø¢': ['\uFE81', '\uFE82', null, null],
    'Ø£': ['\uFE83', '\uFE84', null, null],
    'Ø¤': ['\uFE85', '\uFE86', null, null],
    'Ø¥': ['\uFE87', '\uFE88', null, null],
    'Ø¦': ['\uFE89', '\uFE8A', '\uFE8B', '\uFE8C'],
    'Ø§': ['\uFE8D', '\uFE8E', null, null],
    'Ø¨': ['\uFE8F', '\uFE90', '\uFE91', '\uFE92'],
    'Ø©': ['\uFE93', '\uFE94', null, null],
    'Øª': ['\uFE95', '\uFE96', '\uFE97', '\uFE98'],
    'Ø«': ['\uFE99', '\uFE9A', '\uFE9B', '\uFE9C'],
    'Ø¬': ['\uFE9D', '\uFE9E', '\uFE9F', '\uFEA0'],
    'Ø­': ['\uFEA1', '\uFEA2', '\uFEA3', '\uFEA4'],
    'Ø®': ['\uFEA5', '\uFEA6', '\uFEA7', '\uFEA8'],
    'Ø¯': ['\uFEA9', '\uFEAA', null, null],
    'Ø°': ['\uFEAB', '\uFEAC', null, null],
    'Ø±': ['\uFEAD', '\uFEAE', null, null],
    'Ø²': ['\uFEAF', '\uFEB0', null, null],
    'Ø³': ['\uFEB1', '\uFEB2', '\uFEB3', '\uFEB4'],
    'Ø´': ['\uFEB5', '\uFEB6', '\uFEB7', '\uFEB8'],
    'Øµ': ['\uFEB9', '\uFEBA', '\uFEBB', '\uFEBC'],
    'Ø¶': ['\uFEBD', '\uFEBE', '\uFEBF', '\uFEC0'],
    'Ø·': ['\uFEC1', '\uFEC2', '\uFEC3', '\uFEC4'],
    'Ø¸': ['\uFEC5', '\uFEC6', '\uFEC7', '\uFEC8'],
    'Ø¹': ['\uFEC9', '\uFECA', '\uFECB', '\uFECC'],
    'Øº': ['\uFECD', '\uFECE', '\uFECF', '\uFED0'],
    'Ù': ['\uFED1', '\uFED2', '\uFED3', '\uFED4'],
    'Ù‚': ['\uFED5', '\uFED6', '\uFED7', '\uFED8'],
    'Ùƒ': ['\uFED9', '\uFEDA', '\uFEDB', '\uFEDC'],
    'Ù„': ['\uFEDD', '\uFEDE', '\uFEDF', '\uFEE0'],
    'Ù…': ['\uFEE1', '\uFEE2', '\uFEE3', '\uFEE4'],
    'Ù†': ['\uFEE5', '\uFEE6', '\uFEE7', '\uFEE8'],
    'Ù‡': ['\uFEE9', '\uFEEA', '\uFEEB', '\uFEEC'],
    'Ùˆ': ['\uFEED', '\uFEEE', null, null],
    'Ù‰': ['\uFEEF', '\uFEF0', null, null],
    'ÙŠ': ['\uFEF1', '\uFEF2', '\uFEF3', '\uFEF4'],
  };

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
      'fr': 'FR (br/min)',
      'temperature': 'Temp (C)',
      'glucose': 'Glucose (mg/dl)',
      'spo2': 'SpO2 (%)',
      'spo2_before': 'SpO2 Before (%)',
      'spo2_after': 'SpO2 After (%)',
    };
    return labels[key] ?? key;
  }

  static String _formatNeedLabel(String key) {
    const labels = {
      'oxygen': 'Oxygene',
      'oxygene': 'Oxygene',
      'perfusion': 'Perfusion',
      'monitorage': 'Monitorage',
      'pensement': 'Pansement',
      'immobilisation': 'Immobilisation',
      'vni': 'VNI',
      'vc': 'VC',
      'pep': 'PEP',
      'aide': 'Aide',
      'vcc': 'fie2+vc',
      'v.cabot': 'Courant',
      'fc': 'F.C',
      'pas/pad': 'PAS/PAD',
      'sao2': 'SaO2',
      'destro': 'Dextro',
      'pse': 'PSE',
      'norade': 'Norade',
      'noradrenaline': 'Noradre',
      'adre': 'Adre',
      'adrenalina': 'Adre',
      'sedation': 'Sedation',
      'heparine': 'Heparine',
      'rivotril': 'Rivotril',
      'bb': 'Bigbag',
    };
    return labels[key.toLowerCase()] ?? key;
  }

  static String _getNeedCategory(String key) {
    final vniVcOptions = ['vni', 'pep', 'aide', 'fr', 'vcc', 'vc', 'v.cabot'];
    final vitalSignsParams = ['fc', 'pas/pad', 'sao2', 'destro'];
    final generalSupplies = [
      'oxygen',
      'oxygene',
      'perfusion',
      'monitorage',
      'pensement',
      'immobilisation',
      'bb'
    ];
    final pseOptions = [
      'pse',
      'norade',
      'adre',
      'sedation',
      'heparine',
      'rivotril',
      'noradrenaline',
      'adrenalina'
    ];

    final lowerKey = key.toLowerCase();
    if (vniVcOptions.contains(lowerKey)) return 'VNI/VC';
    if (vitalSignsParams.contains(lowerKey)) return 'Vital Signs';
    if (generalSupplies.contains(lowerKey)) return 'Supplies';
    if (pseOptions.contains(lowerKey)) return 'PSE';
    return 'Other';
  }

  static String _formatMedicalHistoryLabel(String key) {
    const labels = {
      'diabetic': 'Diabetique',
      'hta': 'HTA',
      'douleur_thorasique': 'Douleur Thoracique',
      'dialysis': 'Dialyse',
      'distresse_respiratoire': 'Detresse Respiratoire',
      'hypotension': 'Hypotension',
      'hypalepsie': 'Hypotension',
      'coronaria': 'Maladie Coronarienne',
      'cardiaque': 'Cardiaque',
      'bpco': 'BPCO',
      'asthme': 'Asthme',
      'epilepsie': 'Epilepsie',
    };
    return labels[key.toLowerCase()] ?? key;
  }
  /// Generate and download invoice (facture) PDF for a mission
  static Future<void> generateInvoicePdf(Mission mission) async {
    try {
      debugPrint(
          '[PdfService] Generating Invoice for mission: ${mission.missionNumber}');

      final pdf = pw.Document();

      // Calculate pricing (assuming missionPrice is the total HT)
      double totalHT = 0;
      try {
        totalHT = double.tryParse(mission.missionPrice ?? '0') ?? 0;
      } catch (e) {
        totalHT = 0;
      }

      const double taxRate = 0.19; // 19% TVA for Tunisia
      final double tva = totalHT * taxRate;
      final double totalTTC = totalHT + tva;

      // Generate invoice number based on mission ID (safely handle short IDs)
      final invoiceNumber = mission.id.length >= 6
          ? mission.id.substring(0, 6).toUpperCase()
          : mission.id.padRight(6, '0').toUpperCase();

      // Parse mission date
      DateTime missionDateTime = DateTime.now();
      try {
        missionDateTime = DateTime.parse(mission.missionDate);
      } catch (e) {
        debugPrint('[PdfService] Error parsing mission date: $e');
      }

      final formattedDate =
          '${missionDateTime.day.toString().padLeft(2, '0')}/${missionDateTime.month.toString().padLeft(2, '0')}/${missionDateTime.year}';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(15),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header with company info
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 2, color: PdfColors.red),
                  ),
                ),
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BEDOUI AMBULANCE',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red,
                      ),
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'TRANSPORT MEDICALISE 24H/24H - ADULTE - ENFANT - NOUVEAU NE',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'Avenue Mohamed El Jamoussi Im. Lina 7Ã¨me Ã©tage App. NÂ° 72 - 3000 SFAX',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'TÃ©l: 56 250 250 - 93 903 333  **  E-mail: samibedoui@gmail.com',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                    pw.Text(
                      'MatriculeFiscale: 1516966/W/A/M/000',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 15),

              // Invoice Title
              pw.Text(
                'FACTURE',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 15),

              // Invoice details grid
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          children: [
                            pw.SizedBox(
                              width: 50,
                              child: pw.Text('Patient',
                                  style: const pw.TextStyle(fontSize: 9)),
                            ),
                            pw.Expanded(
                              child: pw.Container(
                                decoration:
                                    pw.BoxDecoration(border: pw.Border.all()),
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 5),
                                child: pw.Text(
                                    (mission.patientName?.isNotEmpty ?? false)
                                        ? mission.patientName!
                                        : ((mission.patientFirstName?.isEmpty ??
                                                    true) &&
                                                (mission.patientLastName
                                                        ?.isEmpty ??
                                                    true))
                                            ? 'N/A'
                                            : '${mission.patientFirstName ?? ''} ${mission.patientLastName ?? ''}'
                                                .trim(),
                                    style: const pw.TextStyle(fontSize: 9)),
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 8),
                        pw.Row(
                          children: [
                            pw.SizedBox(
                              width: 90,
                              child: pw.Text('Ambulancier',
                                  style: const pw.TextStyle(fontSize: 9)),
                            ),
                            pw.Expanded(
                              child: pw.Container(
                                decoration:
                                    pw.BoxDecoration(border: pw.Border.all()),
                                padding: const pw.EdgeInsets.symmetric(
                                    horizontal: 5),
                                child: pw.Text(mission.driverName ?? '',
                                    style: const pw.TextStyle(fontSize: 9)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),

              // Locations
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('LIEU DE DÃ‰PART',
                            style: pw.TextStyle(
                                fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Container(
                          decoration: pw.BoxDecoration(border: pw.Border.all()),
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                          height: 20,
                          child: pw.Center(
                            child: pw.Text(mission.fromLocation,
                                style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('LIEU DE DESTINATION',
                            style: pw.TextStyle(
                                fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Container(
                          decoration: pw.BoxDecoration(border: pw.Border.all()),
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5),
                          height: 20,
                          child: pw.Center(
                            child: pw.Text(mission.toLocation,
                                style: const pw.TextStyle(fontSize: 9)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // Items table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.black,
                  width: 1,
                ),
                children: [
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: PdfColors.grey300),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('DESIGNATION',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('QUANTITE',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('MONTANT',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  ),
                  // First item row
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('Service de Transport MÃ©dical',
                            style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('1',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(fontSize: 9)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Text('${totalHT.toStringAsFixed(3)} DT',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(fontSize: 9)),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 15),

              // Footer with signature and total amount
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('Cachet & Signature',
                            style: pw.TextStyle(
                                fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Container(
                          height: 40,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('MONTANT',
                            style: pw.TextStyle(
                                fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Container(
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(width: 2),
                          ),
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 5, vertical: 8),
                          child: pw.Text('${totalHT.toStringAsFixed(3)} DT',
                              style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      // Generate PDF bytes
      final pdfBytes = await pdf.save();
      debugPrint(
          '[PdfService] Invoice PDF generated (${pdfBytes.length} bytes)');

      // Share PDF
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Facture_${mission.missionNumber}.pdf',
      );
      debugPrint('[PdfService] Invoice PDF shared successfully');
    } catch (e) {
      debugPrint('[PdfService] ERROR generating invoice: $e');
      rethrow;
    }
  }
}




