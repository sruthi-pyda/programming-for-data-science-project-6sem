import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'screens/insights_screen.dart';
import 'screens/prediction_screen.dart';
import 'services/api_service.dart';

// ── App Colour Palette ────────────────────────────────────────────────────────
abstract final class AppColors {
  // Primary
  static const navy      = Color(0xFF1D3557); // app bar, nav bar background
  static const steel     = Color(0xFF457B9D); // secondary accents
  static const crimson   = Color(0xFFE63946); // active indicator, highlights

  // Accent
  static const teal      = Color(0xFF2A9D8F); // positive / safe
  static const amber     = Color(0xFFE9C46A); // warning / medium risk
  static const purple    = Color(0xFF6A4C93); // demographic charts
  static const green     = Color(0xFF43AA8B); // spatial / location

  // Nav bar
  static const navBg          = navy;
  static const navIndicator   = crimson;
  static const navIconUnsel   = Colors.white54;
  static const navIconSel     = Colors.white;
  static const navLabelSel    = Colors.white;
  static const navLabelUnsel  = Colors.white54;
}
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>(create: (_) => ApiService()),
      ],
      child: const RoadSafetyApp(),
    ),
  );
}

class RoadSafetyApp extends StatelessWidget {
  const RoadSafetyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Road Safety Intelligence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.crimson,
          brightness: Brightness.light,
        ),
        textTheme: GoogleFonts.interTextTheme(),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.navBg,
          indicatorColor: AppColors.navIndicator,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return GoogleFonts.inter(
              fontSize: 11,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              color: selected ? AppColors.navLabelSel : AppColors.navLabelUnsel,
            );
          }),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  static const List<_NavItem> _navItems = [
    _NavItem(icon: Icons.home_rounded,      label: 'Home'),
    _NavItem(icon: Icons.insights_rounded,  label: 'Insights'),
    _NavItem(icon: Icons.model_training,    label: 'Predict'),
  ];

  static const List<Widget> _screens = [
    HomeScreen(),
    InsightsScreen(),
    PredictionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: _navItems
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon, color: AppColors.navIconUnsel),
                  selectedIcon: Icon(item.icon, color: AppColors.navIconSel),
                  label: item.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
