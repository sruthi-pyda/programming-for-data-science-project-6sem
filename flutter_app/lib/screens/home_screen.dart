import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1D3557), Color(0xFFE63946)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Icon(Icons.shield_rounded, color: Colors.white, size: 40),
                        const SizedBox(height: 8),
                        Text(
                          'Road Safety\nIntelligence',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          'LA Traffic Collision Analysis',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _SectionCard(
                  icon: Icons.warning_amber_rounded,
                  iconColor: const Color(0xFFE63946),
                  title: 'Problem Statement',
                  body:
                      'Traffic collisions are a leading cause of injury and death in Los Angeles. '
                      'With 600,000+ historical incidents, identifying high-risk zones, dangerous '
                      'times, and vulnerable demographics is critical for proactive road safety planning.',
                ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.15),

                const SizedBox(height: 12),

                _SectionCard(
                  icon: Icons.storage_rounded,
                  iconColor: const Color(0xFF457B9D),
                  title: 'Dataset',
                  body:
                      'City of Los Angeles — LAPD Traffic Collision Records\n'
                      '• Source: data.lacity.org\n'
                      '• Coverage: 2010 to present\n'
                      '• Size: 600,000+ records\n'
                      '• License: Creative Commons CC0 (Public Domain)',
                ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.15),

                const SizedBox(height: 12),

                const _StatsRow(),

                const SizedBox(height: 12),

                _SectionCard(
                  icon: Icons.groups_rounded,
                  iconColor: const Color(0xFF2A9D8F),
                  title: 'Who Benefits',
                  body:
                      '• Traffic Police — optimise patrol allocations\n'
                      '• Urban Planners — data-driven road design\n'
                      '• Emergency Services — faster response deployment\n'
                      '• Insurance Companies — refined risk-based premiums\n'
                      '• General Public — safer commute awareness',
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms).slideY(begin: 0.15),

                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(body, style: GoogleFonts.inter(fontSize: 13.5, height: 1.6)),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatChip(value: '600K+', label: 'Records'),
        const SizedBox(width: 10),
        _StatChip(value: '15 yrs', label: 'Coverage'),
        const SizedBox(width: 10),
        _StatChip(value: '21', label: 'LAPD Areas'),
      ]
          .map((w) => Expanded(child: w))
          .toList()
          .cast<Widget>(),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;

  const _StatChip({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1D3557),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value,
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 2),
          Text(label,
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 11)),
        ],
      ),
    );
  }
}
