import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'call_v2_physical_diagnostic_ledger.dart';

class CallV2PhysicalDiagnosticsView extends StatefulWidget {
  const CallV2PhysicalDiagnosticsView({
    super.key,
    this.ledger,
  });

  final CallV2PhysicalDiagnosticLedger? ledger;

  @override
  State<CallV2PhysicalDiagnosticsView> createState() =>
      _CallV2PhysicalDiagnosticsViewState();
}

class _CallV2PhysicalDiagnosticsViewState
    extends State<CallV2PhysicalDiagnosticsView> {
  late final CallV2PhysicalDiagnosticLedger _ledger =
      widget.ledger ?? CallV2PhysicalDiagnosticLedger.instance;
  bool _refreshing = true;
  String? _report;

  @override
  void initState() {
    super.initState();
    _loadInitialReport();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Call V2 diagnostics',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  key: const ValueKey<String>('call-v2-diagnostics-refresh'),
                  tooltip: 'Refresh diagnostics',
                  onPressed: _refreshing ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  key: const ValueKey<String>('call-v2-diagnostics-copy'),
                  tooltip: 'Copy diagnostics',
                  onPressed: _refreshing ? null : _copyLatestReport,
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _report == null
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: SelectableText(
                        _report!,
                        key: const ValueKey<String>(
                          'call-v2-diagnostics-report',
                        ),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadInitialReport() async {
    await _ledger.refreshNativeTimeline();
    if (!mounted) return;
    setState(() {
      _report = _ledger.buildSafeReport();
      _refreshing = false;
    });
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _ledger.refreshNativeTimeline();
    if (!mounted) return;
    setState(() {
      _report = _ledger.buildSafeReport();
      _refreshing = false;
    });
  }

  Future<void> _copyLatestReport() async {
    setState(() => _refreshing = true);
    await _ledger.refreshNativeTimeline();
    final report = _ledger.buildSafeReport();
    await Clipboard.setData(ClipboardData(text: report));
    if (!mounted) return;
    setState(() {
      _report = report;
      _refreshing = false;
    });
  }
}

class CallV2PhysicalDiagnosticsOverlay extends StatelessWidget {
  const CallV2PhysicalDiagnosticsOverlay({
    super.key,
    required this.child,
    required this.enabled,
    required this.navigatorKey,
    this.ledger,
  });

  final Widget child;
  final bool enabled;
  final GlobalKey<NavigatorState> navigatorKey;
  final CallV2PhysicalDiagnosticLedger? ledger;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        child,
        Positioned(
          right: 8,
          bottom: 84,
          child: SafeArea(
            child: Semantics(
              label: 'Call diagnostics',
              button: true,
              child: Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                elevation: 2,
                shape: const CircleBorder(),
                child: IconButton(
                  key: const ValueKey<String>('call-v2-diagnostics-open'),
                  onPressed: () {
                    final navigatorContext =
                        navigatorKey.currentState?.overlay?.context;
                    if (navigatorContext == null) return;
                    showModalBottomSheet<void>(
                      context: navigatorContext,
                      useSafeArea: true,
                      isScrollControlled: true,
                      builder: (_) => FractionallySizedBox(
                        heightFactor: 0.8,
                        child: CallV2PhysicalDiagnosticsView(ledger: ledger),
                      ),
                    );
                  },
                  icon: const Icon(Icons.bug_report_outlined),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
