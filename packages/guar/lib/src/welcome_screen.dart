// Greeting that opens an existing ledger file or creates a new one.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:guar/src/ledger_documents.dart';

const EdgeInsets _pagePadding = EdgeInsets.symmetric(horizontal: 28, vertical: 36);

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({required this.documents, super.key});

  final LedgerDocuments documents;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _busy = false;
  String? _error;
  LedgerDocument? _chosen;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final LedgerDocument? chosen = _chosen;
    final String? error = _error;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double leftover = constraints.maxHeight - _pagePadding.vertical;
            final double minHeight = leftover < 0 ? 0 : leftover;
            return SingleChildScrollView(
              padding: _pagePadding,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Text(
                          'Guar',
                          style: text.displaySmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.8),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Welcome. Pick a Beancount file to keep your ledger in.',
                          style: text.titleMedium?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Open a file you already have, or create a new ledger and choose where it should live.',
                          style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        if (chosen != null) ...<Widget>[
                          const SizedBox(height: 28),
                          _SelectedLedger(name: chosen.displayName),
                        ],
                        if (error != null) ...<Widget>[
                          const SizedBox(height: 20),
                          Text(error, style: text.bodyMedium?.copyWith(color: colors.error)),
                        ],
                        if (_busy) ...<Widget>[
                          const SizedBox(height: 20),
                          const LinearProgressIndicator(),
                        ],
                        const SizedBox(height: 32),
                        _Choice(
                          label: 'Open a ledger',
                          detail: 'Android will ask you to allow access to that file.',
                          onPressed: _busy ? null : () => unawaited(_open()),
                          primary: true,
                        ),
                        const SizedBox(height: 20),
                        _Choice(
                          label: 'Create a new ledger',
                          detail: 'You choose the folder and the file name.',
                          onPressed: _busy ? null : () => unawaited(_create()),
                          primary: false,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _load() async {
    try {
      final LedgerDocument? document = await widget.documents.current();
      if (!mounted || _busy || _chosen != null) {
        return;
      }
      setState(() => _chosen = document);
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = _message(error));
    }
  }

  Future<void> _open() => _choose(widget.documents.openExisting);

  Future<void> _create() => _choose(widget.documents.createNew);

  Future<void> _choose(Future<LedgerDocument?> Function() pick) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final LedgerDocument? document = await pick();
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        if (document != null) {
          _chosen = document;
        }
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = _message(error);
      });
    }
  }

  String _message(PlatformException error) {
    final String? message = error.message;
    if (message == null || message.isEmpty) {
      return 'Could not use that file.';
    }
    return message;
  }
}

class _SelectedLedger extends StatelessWidget {
  const _SelectedLedger({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Selected file', style: text.labelLarge?.copyWith(color: colors.onPrimaryContainer)),
            const SizedBox(height: 4),
            Text(name, style: text.titleMedium?.copyWith(color: colors.onPrimaryContainer)),
          ],
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.detail, required this.onPressed, required this.primary});

  final String label;
  final String detail;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Widget button = primary
        ? FilledButton(onPressed: onPressed, child: Text(label))
        : FilledButton.tonal(onPressed: onPressed, child: Text(label));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        button,
        const SizedBox(height: 8),
        Text(detail, style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
      ],
    );
  }
}
