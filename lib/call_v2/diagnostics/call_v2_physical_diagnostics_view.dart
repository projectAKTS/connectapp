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
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    final report = _ledger.buildSafeReport();
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
                  onPressed: () =>
                      Clipboard.setData(ClipboardData(text: report)),
                  icon: const Icon(Icons.copy),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  report,
                  key: const ValueKey<String>('call-v2-diagnostics-report'),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    await _ledger.refreshNativeTimeline();
    if (!mounted) return;
    setState(() => _refreshing = false);
  }
}

class CallV2PhysicalDiagnosticsOverlay extends StatelessWidget {
  const CallV2PhysicalDiagnosticsOverlay({
    super.key,
    required this.child,
    required this.enabled,
  });

  final Widget child;
  final bool enabled;

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
            child: IconButton.filledTonal(
              key: const ValueKey<String>('call-v2-diagnostics-open'),
              tooltip: 'Call diagnostics',
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  useSafeArea: true,
                  isScrollControlled: true,
                  builder: (_) => const FractionallySizedBox(
                    heightFactor: 0.8,
                    child: CallV2PhysicalDiagnosticsView(),
                  ),
                );
              },
              icon: const Icon(Icons.bug_report_outlined),
            ),
          ),
        ),
      ],
    );
  }
}
