import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  static const List<_Insight> _insights = [
    _Insight(
      icon: Icons.access_time_rounded,
      color: Color(0xFFE63946),
      title: 'Peak Danger Hours',
      finding: 'Collisions spike sharply between 5–7 PM (evening rush) and again at midnight. '
          'The 5–6 PM hour consistently records the highest single-hour count across all years.',
      implication: 'Increased police presence and traffic signal optimisation during evening rush can reduce incidents by an estimated 15–20%.',
    ),
    _Insight(
      icon: Icons.calendar_today_rounded,
      color: Color(0xFF457B9D),
      title: 'Weekly Patterns',
      finding: 'Fridays record the highest collision count, followed by Thursdays. '
          'Weekends show a shift toward late-night incidents (10 PM–2 AM), likely alcohol-related.',
      implication: 'DUI checkpoints should be concentrated on Friday/Saturday nights in high-risk areas.',
    ),
    _Insight(
      icon: Icons.map_rounded,
      color: Color(0xFF2A9D8F),
      title: 'High-Risk Zones',
      finding: 'The 77th Street, Southeast, and Central LAPD divisions consistently rank highest. '
          'Hotspot clusters are concentrated around major intersections on Florence Ave, '
          'Vermont Ave, and the I-110 corridor.',
      implication: 'Infrastructure improvements (lighting, signage, signal timing) at these specific intersections would have maximum impact.',
    ),
    _Insight(
      icon: Icons.people_alt_rounded,
      color: Color(0xFFE9C46A),
      title: 'Vulnerable Demographics',
      finding: 'Adults aged 26–40 are the most frequently involved group (35% of victims). '
          'Male victims outnumber female by approximately 1.6:1. '
          'Hispanic/Latino and Black communities are disproportionately affected.',
      implication: 'Targeted road safety campaigns and community outreach should prioritise these demographics.',
    ),
    _Insight(
      icon: Icons.directions_rounded,
      color: Color(0xFF6A4C93),
      title: 'Premise Types',
      finding: 'Over 70% of collisions occur on streets (not parking lots or driveways). '
          'Sidewalk collisions, while smaller in count, carry higher pedestrian injury severity.',
      implication: 'Pedestrian crossing improvements and reduced speed limits in residential corridors would protect the most vulnerable road users.',
    ),
    _Insight(
      icon: Icons.trending_down_rounded,
      color: Color(0xFF43AA8B),
      title: 'Long-Term Trend',
      finding: 'Collision counts peaked around 2015–2016, then declined through 2020 '
          '(partially attributed to COVID-19 lockdowns). Post-2021 shows a gradual recovery '
          'toward pre-pandemic levels.',
      implication: 'Policy interventions implemented in 2017–2018 appear to have contributed to the downward trend — maintaining these measures is essential.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Key Insights',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _insights.length,
        itemBuilder: (context, i) => _InsightCard(insight: _insights[i])
            .animate()
            .fadeIn(duration: 350.ms, delay: (i * 80).ms)
            .slideX(begin: 0.1),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final _Insight insight;
  const _InsightCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: insight.color.withValues(alpha: 0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: insight.color.withValues(alpha: 0.15),
            child: Icon(insight.icon, color: insight.color, size: 20),
          ),
          title: Text(insight.title,
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('Finding'),
                  Text(insight.finding,
                      style: GoogleFonts.inter(fontSize: 13, height: 1.6)),
                  const SizedBox(height: 10),
                  _Label('Implication'),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: insight.color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(insight.implication,
                        style: GoogleFonts.inter(fontSize: 13, height: 1.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text.toUpperCase(),
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.grey.shade500)),
    );
  }
}

class _Insight {
  final IconData icon;
  final Color color;
  final String title;
  final String finding;
  final String implication;

  const _Insight({
    required this.icon, required this.color, required this.title,
    required this.finding, required this.implication,
  });
}
