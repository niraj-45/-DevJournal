import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/providers/workspace_provider.dart';

class StandupScreen extends ConsumerStatefulWidget {
  const StandupScreen({super.key});

  @override
  ConsumerState<StandupScreen> createState() => _StandupScreenState();
}

class _StandupScreenState extends ConsumerState<StandupScreen> {
  late TextEditingController _controller;
  bool _edited = false;       // true only when user has manually typed
  String _lastGenerated = ''; // last text we auto-generated (for change detection)
  bool _copied = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _prefsKey(String workspaceId, DateTime date) =>
      'standup_${workspaceId}_${DateFormat('yyyy-MM-dd').format(date)}';

  Future<void> _saveToPrefs(String workspaceId, DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey(workspaceId, date), _controller.text);
    if (mounted) {
      setState(() => _saved = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _saved = false);
    }
  }

  String _buildStandup(List<SessionWithMood> sessions, DateTime date) {
    final label = DateFormat('EEEE, MMM d').format(date);
    final buffer = StringBuffer();

    buffer.writeln('📋 Standup — $label');
    buffer.writeln();

    final withTicket = sessions.where((s) => s.session.ticketId?.isNotEmpty == true).toList();

    buffer.writeln('✅ What I worked on:');
    if (sessions.isEmpty) {
      buffer.writeln('• No sessions logged');
    } else {
      for (final s in sessions.reversed) {
        final ticket = s.session.ticketId?.isNotEmpty == true
            ? '[${s.session.ticketId}]'
            : '[no ticket]';
        final dur = s.session.formattedDuration;
        buffer.writeln('• $ticket — $dur');
      }
    }

    final blockers = sessions.where((s) => s.blocker?.isNotEmpty == true).toList();
    buffer.writeln();
    buffer.writeln('🚧 Blockers:');
    if (blockers.isEmpty) {
      buffer.writeln('• None');
    } else {
      for (final s in blockers) {
        final ticket = s.session.ticketId?.isNotEmpty == true
            ? '[${s.session.ticketId}] '
            : '';
        buffer.writeln('• $ticket${s.blocker}');
      }
    }

    final totalSeconds = sessions.fold<int>(0, (sum, s) => sum + (s.session.durationSeconds ?? 0));
    final totalH = totalSeconds ~/ 3600;
    final totalM = (totalSeconds % 3600) ~/ 60;
    final totalStr = totalH > 0 ? '${totalH}h ${totalM}m' : '${totalM}m';

    if (withTicket.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('⏱ Total tracked: $totalStr across ${sessions.length} session${sessions.length == 1 ? '' : 's'}');
    }

    return buffer.toString().trim();
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _controller.text));
    setState(() => _copied = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final date = dateOnly(ref.watch(selectedDateProvider));
    final sessionsAsync = ref.watch(sessionsForDateProvider(date));
    final isToday = date == dateOnly(DateTime.now());
    final dateLabel = isToday ? 'Today' : DateFormat('EEE, MMM d').format(date);
    final wsAsync = ref.watch(workspaceProvider);
    final workspaceId = wsAsync.valueOrNull?['id'] as String?;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSecondary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
              onPressed: () {
                ref.read(selectedDateProvider.notifier).state =
                    date.subtract(const Duration(days: 1));
                setState(() { _edited = false; _lastGenerated = ''; _saved = false; });
              },
            ),
            GestureDetector(
              onTap: isToday
                  ? null
                  : () {
                      ref.read(selectedDateProvider.notifier).state = DateTime.now();
                      setState(() { _edited = false; _lastGenerated = ''; _saved = false; });
                    },
              child: Text(dateLabel,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded,
                  color: isToday ? AppColors.surfaceBg : AppColors.textSecondary),
              onPressed: isToday
                  ? null
                  : () {
                      ref.read(selectedDateProvider.notifier).state =
                          date.add(const Duration(days: 1));
                      setState(() { _edited = false; _lastGenerated = ''; _saved = false; });
                    },
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
              onPressed: () {
              ref.invalidate(sessionsForDateProvider(date));
              setState(() { _edited = false; _lastGenerated = ''; _saved = false; });
            },
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.mediumBlue)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load sessions',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(sessionsForDateProvider(date)),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.mediumBlue),
                child: const Text('Retry', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
        data: (sessions) {
          // On first load (or when date/sessions changed and user hasn't edited),
          // check for a previously saved standup; fall back to generated text.
          if (!_edited) {
            final generated = _buildStandup(sessions, date);
            if (generated != _lastGenerated) {
              // Sessions changed (first load, deletion, new session, etc.)
              // — always regenerate from live data.
              _lastGenerated = generated;
              _controller.text = generated;
              _controller.selection =
                  TextSelection.collapsed(offset: generated.length);
            }
          }

          return Column(
            children: [
              // Stats row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _StatsRow(sessions: sessions),
              ),

              const SizedBox(height: 12),

              // Editable standup text
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _edited
                            ? AppColors.mediumBlue.withOpacity(0.4)
                            : AppColors.surfaceBg,
                      ),
                    ),
                    child: TextField(
                      controller: _controller,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 1.7,
                        fontFamily: 'monospace',
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(16),
                      ),
                      onChanged: (_) => setState(() => _edited = true),
                    ),
                  ),
                ),
              ),

              if (_edited)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: TextButton.icon(
                    onPressed: () {
                      final generated = _buildStandup(sessions, date);
                      _lastGenerated = generated;
                      _controller.text = generated;
                      setState(() => _edited = false);
                    },
                    icon: const Icon(Icons.undo_rounded, size: 16, color: AppColors.textSecondary),
                    label: const Text('Reset to generated',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ),
                ),

              // Action buttons
              Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 16),
                child: Row(
                  children: [
                    // Save button
                    Expanded(
                      child: _ActionButton(
                        icon: _saved ? Icons.check_rounded : Icons.save_rounded,
                        label: _saved ? 'Saved!' : 'Save',
                        color: _saved ? AppColors.success : AppColors.textSecondary,
                        onTap: workspaceId == null
                            ? () {}
                            : () => _saveToPrefs(workspaceId, date),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Copy button
                    Expanded(
                      flex: 2,
                      child: _ActionButton(
                        icon: _copied ? Icons.check_rounded : Icons.copy_rounded,
                        label: _copied ? 'Copied!' : 'Copy',
                        color: _copied ? AppColors.success : AppColors.mediumBlue,
                        onTap: _copyToClipboard,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final List<SessionWithMood> sessions;
  const _StatsRow({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final totalSeconds = sessions.fold<int>(0, (sum, s) => sum + (s.session.durationSeconds ?? 0));
    final totalH = totalSeconds ~/ 3600;
    final totalM = (totalSeconds % 3600) ~/ 60;
    final totalStr = totalH > 0 ? '${totalH}h ${totalM}m' : '${totalM}m';

    final avgFocus = sessions.where((s) => s.focusScore != null).isNotEmpty
        ? sessions.where((s) => s.focusScore != null).map((s) => s.focusScore!).reduce((a, b) => a + b) /
            sessions.where((s) => s.focusScore != null).length
        : null;
    final avgEnergy = sessions.where((s) => s.energyScore != null).isNotEmpty
        ? sessions.where((s) => s.energyScore != null).map((s) => s.energyScore!).reduce((a, b) => a + b) /
            sessions.where((s) => s.energyScore != null).length
        : null;

    return Row(
      children: [
        _StatChip(label: 'Time', value: sessions.isEmpty ? '0m' : totalStr),
        const SizedBox(width: 8),
        _StatChip(label: 'Sessions', value: '${sessions.length}'),
        if (avgFocus != null) ...[
          const SizedBox(width: 8),
          _StatChip(label: 'Focus', value: avgFocus.toStringAsFixed(1)),
        ],
        if (avgEnergy != null) ...[
          const SizedBox(width: 8),
          _StatChip(label: 'Energy', value: avgEnergy.toStringAsFixed(1)),
        ],
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
