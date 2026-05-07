import 'package:flutter/material.dart';

import '../models/mission_model.dart';

class PatientRequestSummaryCard extends StatelessWidget {
  const PatientRequestSummaryCard({
    super.key,
    required this.mission,
    this.dense = false,
    this.accentColor = const Color(0xFF0F766E),
  });

  final Mission mission;
  final bool dense;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (!mission.hasPatientRequestDetails) {
      return const SizedBox.shrink();
    }

    final chips = _buildChips();
    final visibleChips = dense
        ? chips.take(3).toList()
        : chips.take(5).toList();
    final hiddenCount = chips.length - visibleChips.length;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showPatientNeedsSheet(context),
        child: Ink(
          width: double.infinity,
          padding: EdgeInsets.all(dense ? 10 : 12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accentColor.withValues(alpha: 0.24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.medical_information_outlined,
                    size: 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Besoin patient',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  Text(
                    'Voir',
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 3),
                  Icon(Icons.expand_more_rounded, size: 17, color: accentColor),
                ],
              ),
              if (visibleChips.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...visibleChips.map(
                      (label) => _PatientRequestChip(
                        label: label,
                        accentColor: accentColor,
                      ),
                    ),
                    if (hiddenCount > 0)
                      _PatientRequestChip(
                        label: '+$hiddenCount',
                        accentColor: accentColor,
                      ),
                  ],
                ),
              ],
              if (!dense && mission.patientConditionSummary != null) ...[
                const SizedBox(height: 8),
                Text(
                  mission.patientConditionSummary!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
              if (!dense && mission.patientRequestDestination != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.flag_outlined, size: 14, color: accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        mission.patientRequestDestination!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPatientNeedsSheet(BuildContext context) {
    final details = mission.patientRequestDetails;
    final rows =
        <_PatientRequestDetail>[
              _PatientRequestDetail(
                'Type de demande',
                mission.patientRequestType,
              ),
              _PatientRequestDetail('Mobilité', mission.patientRequestMobility),
              _PatientRequestDetail(
                'Priorité',
                _readDetail(details, 'priority'),
              ),
              _PatientRequestDetail(
                'Planification',
                mission.patientRequestScheduledAt,
              ),
              _PatientRequestDetail(
                'Destination',
                mission.patientRequestDestination,
              ),
              _PatientRequestDetail(
                'État patient',
                mission.patientConditionSummary,
              ),
            ]
            .where((row) => row.value != null && row.value!.trim().isNotEmpty)
            .toList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.82,
            ),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.medical_information_outlined,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Besoin patient',
                          style: TextStyle(
                            color: Color(0xFF111827),
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (rows.isNotEmpty)
                    ...rows.map(
                      (row) => _PatientRequestDetailRow(
                        label: row.label,
                        value: row.value!,
                        accentColor: accentColor,
                      ),
                    ),
                  if (mission.patientNeedLabels.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Besoins médicaux',
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: mission.patientNeedLabels
                          .map(
                            (label) => _PatientRequestChip(
                              label: label,
                              accentColor: accentColor,
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (rows.isEmpty && mission.patientNeedLabels.isEmpty)
                    const Text(
                      'Aucun détail supplémentaire disponible.',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String? _readDetail(Map<String, dynamic> details, String key) {
    final value = details[key];
    if (value == null) {
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  List<String> _buildChips() {
    final chips = <String>[];
    void add(String? value) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty && !chips.contains(text)) {
        chips.add(text);
      }
    }

    add(mission.patientRequestType);
    add(mission.patientRequestMobility);
    if (mission.patientRequestScheduledAt != null) {
      add('Planifié ${mission.patientRequestScheduledAt}');
    }
    for (final need in mission.patientNeedLabels) {
      add(need);
    }
    return chips;
  }
}

class _PatientRequestDetail {
  const _PatientRequestDetail(this.label, this.value);

  final String label;
  final String? value;
}

class _PatientRequestDetailRow extends StatelessWidget {
  const _PatientRequestDetailRow({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  final String label;
  final String value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientRequestChip extends StatelessWidget {
  const _PatientRequestChip({required this.label, required this.accentColor});

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: accentColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
