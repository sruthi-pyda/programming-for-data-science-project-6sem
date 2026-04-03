import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  // ── Form state ──────────────────────────────────────────────────────────────
  int _area = 1;
  int _hour = 8;
  int _month = 1;
  int _premis = 101;
  double _age = 35;

  PredictionResult? _result;
  bool _loading = false;
  String? _error;

  static const Map<int, String> _areaNames = {
    1: 'Central', 2: 'Rampart', 3: 'Southwest', 4: 'Hollenbeck',
    5: 'Harbor', 6: 'Hollywood', 7: 'Wilshire', 8: 'West LA',
    9: 'Van Nuys', 10: 'West Valley', 11: 'Northeast', 12: 'Newton',
    13: 'Olympic', 14: 'Mission', 15: 'N Hollywood', 16: 'Foothill',
    17: 'Devonshire', 18: 'Southeast', 19: 'Pacific', 20: 'Topanga', 21: 'Rampart',
  };

  static const Map<int, String> _premisNames = {
    101: 'Street', 102: 'Sidewalk', 108: 'Parking Lot',
    501: 'Single Family Dwelling', 502: 'Multi-Unit Dwelling',
  };

  static const List<String> _monthNames = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  Future<void> _runPrediction() async {
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final api = context.read<ApiService>();
      final result = await api.predict(
        area: _area,
        hour: _hour,
        monthNum: _month,
        premisCd: _premis,
        avgVictimAge: _age,
      );
      setState(() => _result = result);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Color _riskColor(String? level) => switch (level) {
        'High'   => const Color(0xFFE63946),
        'Medium' => const Color(0xFFE9C46A),
        'Low'    => const Color(0xFF2A9D8F),
        _        => Colors.grey,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Risk Prediction',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Inputs ──────────────────────────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prediction Inputs',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),

                    _DropdownField<int>(
                      label: 'LAPD Area',
                      value: _area,
                      items: _areaNames.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _area = v!),
                    ),

                    _SliderField(
                      label: 'Hour of Day',
                      value: _hour.toDouble(),
                      min: 0, max: 23, divisions: 23,
                      display: '$_hour:00',
                      onChanged: (v) => setState(() => _hour = v.round()),
                    ),

                    _SliderField(
                      label: 'Month',
                      value: _month.toDouble(),
                      min: 1, max: 12, divisions: 11,
                      display: _monthNames[_month],
                      onChanged: (v) => setState(() => _month = v.round()),
                    ),

                    _DropdownField<int>(
                      label: 'Premise Type',
                      value: _premis,
                      items: _premisNames.entries
                          .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                          .toList(),
                      onChanged: (v) => setState(() => _premis = v!),
                    ),

                    _SliderField(
                      label: 'Avg Victim Age',
                      value: _age,
                      min: 10, max: 80, divisions: 70,
                      display: _age.round().toString(),
                      onChanged: (v) => setState(() => _age = v),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _loading ? null : _runPrediction,
              icon: _loading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.model_training),
              label: Text(_loading ? 'Predicting...' : 'Predict Risk Level',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),

            // ── Error ────────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Could not reach the R API.\nMake sure run_api.R is running.\n\n$_error',
                  style: GoogleFonts.inter(fontSize: 12, color: Colors.red.shade700),
                ),
              ),
            ],

            // ── Result ────────────────────────────────────────────────────────
            if (_result != null) ...[
              const SizedBox(height: 16),
              _RiskResultCard(result: _result!, riskColor: _riskColor(_result!.riskLevel)),
            ],

            // ── Risk Category Legend ──────────────────────────────────────────
            const SizedBox(height: 20),
            Text('Risk Category Definitions',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            const _RiskLegend(),
          ],
        ),
      ),
    );
  }
}

class _RiskResultCard extends StatelessWidget {
  final PredictionResult result;
  final Color riskColor;
  const _RiskResultCard({required this.result, required this.riskColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: riskColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded, color: riskColor, size: 36),
                const SizedBox(width: 10),
                Text(
                  '${result.riskLevel} Risk',
                  style: GoogleFonts.inter(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: PieChart(PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: result.probLow * 100,
                    color: const Color(0xFF2A9D8F),
                    title: 'L\n${(result.probLow * 100).toStringAsFixed(0)}%',
                    radius: 50, titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  PieChartSectionData(
                    value: result.probMedium * 100,
                    color: const Color(0xFFE9C46A),
                    title: 'M\n${(result.probMedium * 100).toStringAsFixed(0)}%',
                    radius: 50, titleStyle: const TextStyle(fontSize: 11),
                  ),
                  PieChartSectionData(
                    value: result.probHigh * 100,
                    color: const Color(0xFFE63946),
                    title: 'H\n${(result.probHigh * 100).toStringAsFixed(0)}%',
                    radius: 50, titleStyle: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ],
              )),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ProbChip(label: 'Low',    color: const Color(0xFF2A9D8F), pct: result.probLow),
                _ProbChip(label: 'Medium', color: const Color(0xFFE9C46A), pct: result.probMedium),
                _ProbChip(label: 'High',   color: const Color(0xFFE63946), pct: result.probHigh),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProbChip extends StatelessWidget {
  final String label;
  final Color color;
  final double pct;
  const _ProbChip({required this.label, required this.color, required this.pct});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(width: 14, height: 14,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 11)),
        Text('${(pct * 100).toStringAsFixed(1)}%',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _RiskLegend extends StatelessWidget {
  const _RiskLegend();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _LegendRow(color: Color(0xFF2A9D8F), level: 'Low',
            desc: 'Area and time combination historically safe. Normal traffic conditions.'),
        SizedBox(height: 8),
        _LegendRow(color: Color(0xFFE9C46A), level: 'Medium',
            desc: 'Elevated risk. Exercise caution, especially for vulnerable groups.'),
        SizedBox(height: 8),
        _LegendRow(color: Color(0xFFE63946), level: 'High',
            desc: 'Hotspot zone or dangerous time window. High accident concentration.'),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String level;
  final String desc;
  const _LegendRow({required this.color, required this.level, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 3),
          width: 14, height: 14,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(level, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(desc, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade700)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ─────────────────────────────────────────────────────────────

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.label, required this.value,
    required this.items, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<T>(
            initialValue: value, items: items, onChanged: onChanged,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderField extends StatelessWidget {
  final String label;
  final double value;
  final double min, max;
  final int divisions;
  final String display;
  final ValueChanged<double> onChanged;

  const _SliderField({
    required this.label, required this.value,
    required this.min, required this.max,
    required this.divisions, required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: Colors.grey.shade600)),
            const Spacer(),
            Text(display, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
          ]),
          Slider(
            value: value, min: min, max: max, divisions: divisions,
            activeColor: const Color(0xFFE63946),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
