// Layout for one setting: a short explanation, a detail tooltip, and an unused warning.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:guar/l10n/gen/app_localizations.dart';
import 'package:guar/src/settings_copy.dart';

class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    required this.switchKey,
    required this.helpKey,
    required this.label,
    required this.copy,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final Key switchKey;
  final Key helpKey;
  final String label;
  final SettingCopy copy;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final String? warning = copy.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SwitchListTile(
          key: switchKey,
          isThreeLine: copy.summary.length > 48,
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: Text(copy.summary),
          secondary: _SettingHelp(helpKey: helpKey, label: label, detail: copy.detail),
          value: value,
          onChanged: onChanged,
        ),
        if (warning != null) _SettingWarning(text: warning),
      ],
    );
  }
}

class SettingBlock extends StatelessWidget {
  const SettingBlock({
    required this.helpKey,
    required this.label,
    required this.copy,
    required this.child,
    super.key,
  });

  final Key helpKey;
  final String label;
  final SettingCopy copy;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final String? warning = copy.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label, style: text.titleSmall)),
              _SettingHelp(helpKey: helpKey, label: label, detail: copy.detail),
            ],
          ),
          Text(copy.summary, style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
          if (warning != null) _SettingWarning(text: warning),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _SettingHelp extends StatelessWidget {
  const _SettingHelp({required this.helpKey, required this.label, required this.detail});

  final Key helpKey;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) => IconButton(
    key: helpKey,
    tooltip: detail,
    visualDensity: VisualDensity.compact,
    onPressed: () => unawaited(
      showDialog<void>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(label),
          content: SingleChildScrollView(child: Text(detail)),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(GuarLocalizations.of(context).closeLabel),
            ),
          ],
        ),
      ),
    ),
    icon: const Icon(Icons.info_outline),
  );
}

class _SettingWarning extends StatelessWidget {
  const _SettingWarning({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme theme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_outlined, size: 18, color: colors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: theme.bodySmall?.copyWith(color: colors.error)),
          ),
        ],
      ),
    );
  }
}
