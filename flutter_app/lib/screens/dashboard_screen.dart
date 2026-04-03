import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ─────────────────────────────────────────────────────────────────────────
  // REPLACE these placeholder URLs with the real "Publish to Web" embed URLs
  // after you publish each report page from Power BI Desktop.
  //
  // How to get these URLs:
  //   1. Open Power BI Desktop → File → Publish → Publish to Power BI
  //   2. Go to app.powerbi.com → open the report
  //   3. File → Embed report → Publish to web (public)
  //   4. Copy the iframe src URL and paste it below.
  // ─────────────────────────────────────────────────────────────────────────
  static const List<_DashTab> _tabs = [
    _DashTab(
      label: 'Overview',
      icon: Icons.bar_chart_rounded,
      url: 'https://app.powerbi.com/view?r=REPLACE_WITH_OVERVIEW_URL',
    ),
    _DashTab(
      label: 'Time',
      icon: Icons.schedule_rounded,
      url: 'https://app.powerbi.com/view?r=REPLACE_WITH_TIME_URL',
    ),
    _DashTab(
      label: 'Location',
      icon: Icons.map_rounded,
      url: 'https://app.powerbi.com/view?r=REPLACE_WITH_LOCATION_URL',
    ),
    _DashTab(
      label: 'Demographics',
      icon: Icons.people_rounded,
      url: 'https://app.powerbi.com/view?r=REPLACE_WITH_DEMOGRAPHICS_URL',
    ),
    _DashTab(
      label: 'Predictions',
      icon: Icons.model_training,
      url: 'https://app.powerbi.com/view?r=REPLACE_WITH_PREDICTIONS_URL',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Power BI Dashboard',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFFE63946),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          tabs: _tabs
              .map((t) => Tab(icon: Icon(t.icon, size: 18), text: t.label))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((t) => _PowerBiView(url: t.url)).toList(),
      ),
    );
  }
}

class _PowerBiView extends StatefulWidget {
  final String url;
  const _PowerBiView({required this.url});

  @override
  State<_PowerBiView> createState() => _PowerBiViewState();
}

class _PowerBiViewState extends State<_PowerBiView>
    with AutomaticKeepAliveClientMixin {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isPlaceholder = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    _isPlaceholder = widget.url.contains('REPLACE_WITH');

    if (!_isPlaceholder) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() => _isLoading = false),
        ))
        ..loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isPlaceholder) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.dashboard_customize_rounded,
                  size: 64, color: Color(0xFF1D3557)),
              const SizedBox(height: 16),
              Text('Power BI Report',
                  style: GoogleFonts.inter(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                'Publish your Power BI report using\n"Publish to Web" and replace the URL\nin dashboard_screen.dart',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: Color(0xFFE63946))),
      ],
    );
  }
}

class _DashTab {
  final String label;
  final IconData icon;
  final String url;
  const _DashTab({required this.label, required this.icon, required this.url});
}
