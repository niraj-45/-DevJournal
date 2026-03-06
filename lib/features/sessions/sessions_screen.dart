import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/sessions_provider.dart';
import '../../core/models/session_model.dart';

class SessionsScreen extends ConsumerWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedDateProvider);
    final date = dateOnly(selectedDate);
    final sessionsAsync = ref.watch(sessionsForDateProvider(date));
    final isToday = date == dateOnly(DateTime.now());

    final dateLabel = isToday
        ? 'Today'
        : DateFormat('EEE, MMM d').format(date);

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
              onPressed: () => ref.read(selectedDateProvider.notifier).state =
                  date.subtract(const Duration(days: 1)),
            ),
            GestureDetector(
              onTap: isToday
                  ? null
                  : () => ref.read(selectedDateProvider.notifier).state = DateTime.now(),
              child: Text(
                dateLabel,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded,
                  color: isToday ? AppColors.surfaceBg : AppColors.textSecondary),
              onPressed: isToday
                  ? null
                  : () => ref.read(selectedDateProvider.notifier).state =
                      date.add(const Duration(days: 1)),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: () => ref.invalidate(sessionsForDateProvider(date)),
          ),
        ],
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.mediumBlue)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Failed to load sessions',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 16)),
                const SizedBox(height: 8),
                Text(e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(sessionsForDateProvider(date)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.mediumBlue),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.timelapse_rounded, color: AppColors.textSecondary, size: 48),
                  const SizedBox(height: 16),
                  Text(isToday ? 'No sessions today yet' : 'No sessions on this day',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(isToday ? 'Start a timer to log your first session' : 'Try navigating to a different day',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            );
          }

          final totalSeconds = sessions.fold<int>(
            0, (sum, s) => sum + (s.session.durationSeconds ?? 0));
          final totalHours = totalSeconds ~/ 3600;
          final totalMinutes = (totalSeconds % 3600) ~/ 60;
          final totalFormatted = totalHours > 0
              ? '${totalHours}h ${totalMinutes}m'
              : '${totalMinutes}m';

          return RefreshIndicator(
            color: AppColors.mediumBlue,
            backgroundColor: AppColors.cardBg,
            onRefresh: () async => ref.invalidate(todaySessionsProvider),
            child: CustomScrollView(
              slivers: [
                // Summary banner
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.mediumBlue.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.mediumBlue.withOpacity(0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: AppColors.mediumBlue, size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(totalFormatted,
                                  style: const TextStyle(
                                      color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                              const Text('total time tracked today',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.mediumBlue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('${sessions.length} session${sessions.length == 1 ? '' : 's'}',
                                style: const TextStyle(color: AppColors.mediumBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Session cards
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _SessionCard(
                        data: sessions[i],
                        onDelete: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: AppColors.cardBg,
                              title: const Text('Delete session?',
                                  style: TextStyle(color: AppColors.textPrimary)),
                              content: const Text(
                                'This session and its mood log will be permanently deleted.',
                                style: TextStyle(color: AppColors.textSecondary),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel',
                                      style: TextStyle(color: AppColors.textSecondary)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete',
                                      style: TextStyle(color: AppColors.error)),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true && context.mounted) {
                            await deleteSession(sessions[i].session.id, ref);
                          }
                        },
                        onEdit: () => _showEditSheet(context, ref, sessions[i].session),
                      ),
                      childCount: sessions.length,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),

      // Generate Standup FAB
      floatingActionButton: sessionsAsync.maybeWhen(
        data: (sessions) => sessions.isEmpty
            ? null
            : FloatingActionButton.extended(
                backgroundColor: AppColors.mediumBlue,
                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                label: const Text('Generate Standup', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onPressed: () => context.push('/standup'),
              ),
        orElse: () => null,
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final SessionWithMood data;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  const _SessionCard({required this.data, required this.onDelete, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final session = data.session;
    final timeFormat = DateFormat('h:mm a');
    final startStr = timeFormat.format(session.startedAt.toLocal());
    final endStr = session.endedAt != null ? timeFormat.format(session.endedAt!.toLocal()) : '—';
    final hasTicket = session.ticketId?.isNotEmpty == true;
    final hasNotes = session.notes?.isNotEmpty == true;

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; // we handle removal via provider invalidation
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.only(right: 24),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 24),
      ),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.surfaceBg),
          ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Ticket badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: hasTicket
                        ? AppColors.mediumBlue.withOpacity(0.15)
                        : AppColors.surfaceBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasTicket ? session.ticketId! : 'No ticket',
                    style: TextStyle(
                      color: hasTicket ? AppColors.mediumBlue : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                // Duration
                Text(session.formattedDuration,
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),

            // Subtask / notes
            if (hasNotes) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.subject_rounded, color: AppColors.textSecondary, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(session.notes!,
                        style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Time range
            Row(
              children: [
                const Icon(Icons.schedule_rounded, color: AppColors.textSecondary, size: 14),
                const SizedBox(width: 6),
                Text('$startStr  →  $endStr',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),

            // Mood scores
            if (data.focusScore != null || data.energyScore != null) ...[
              const SizedBox(height: 10),
              const Divider(color: AppColors.surfaceBg, height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (data.focusScore != null) ...[
                    _ScoreChip(label: 'Focus', score: data.focusScore!),
                    const SizedBox(width: 8),
                  ],
                  if (data.energyScore != null)
                    _ScoreChip(label: 'Energy', score: data.energyScore!),
                ],
              ),
            ],

            // Blocker
            if (data.blocker?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(data.blocker!,
                        style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

// ── Edit Session Bottom Sheet ─────────────────────────────────────────────────
void _showEditSheet(BuildContext context, WidgetRef ref, SessionModel session) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.cardBg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _EditSessionSheet(session: session),
  );
}

class _EditSessionSheet extends ConsumerStatefulWidget {
  final SessionModel session;
  const _EditSessionSheet({required this.session});

  @override
  ConsumerState<_EditSessionSheet> createState() => _EditSessionSheetState();
}

class _EditSessionSheetState extends ConsumerState<_EditSessionSheet> {
  late TextEditingController _ticketCtrl;
  late TextEditingController _subtaskCtrl;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ticketCtrl = TextEditingController(text: widget.session.ticketId ?? '');
    _subtaskCtrl = TextEditingController(text: widget.session.notes ?? '');
    final local = widget.session.startedAt.toLocal();
    _startTime = TimeOfDay(hour: local.hour, minute: local.minute);
    if (widget.session.endedAt != null) {
      final endLocal = widget.session.endedAt!.toLocal();
      _endTime = TimeOfDay(hour: endLocal.hour, minute: endLocal.minute);
    } else {
      _endTime = TimeOfDay.now();
    }
  }

  @override
  void dispose() {
    _ticketCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  DateTime _dateAt(TimeOfDay t) {
    final base = widget.session.startedAt.toLocal();
    return DateTime(base.year, base.month, base.day, t.hour, t.minute);
  }

  String _fmtDuration(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Future<void> _save() async {
    final ticket = _ticketCtrl.text.trim();
    final subtask = _subtaskCtrl.text.trim();
    if (ticket.isEmpty || subtask.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket ID and subtask are both required'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    var start = _dateAt(_startTime);
    var end = _dateAt(_endTime);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));

    setState(() => _saving = true);
    try {
      await updateSession(
        sessionId: widget.session.id,
        start: start,
        end: end,
        ticketId: ticket,
        notes: subtask,
        ref: ref,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var start = _dateAt(_startTime);
    var end = _dateAt(_endTime);
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    final durationMins = end.difference(start).inMinutes;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Session',
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Time pickers
            Row(
              children: [
                Expanded(
                  child: _EditTimePicker(
                    label: 'Start',
                    time: _startTime,
                    onPick: () async {
                      final picked = await showTimePicker(context: context, initialTime: _startTime);
                      if (picked != null) setState(() => _startTime = picked);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondary),
                const SizedBox(width: 16),
                Expanded(
                  child: _EditTimePicker(
                    label: 'End',
                    time: _endTime,
                    onPick: () async {
                      final picked = await showTimePicker(context: context, initialTime: _endTime);
                      if (picked != null) setState(() => _endTime = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Duration: ${_fmtDuration(durationMins)}',
                style: const TextStyle(color: AppColors.mediumBlue, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 20),

            // Ticket & subtask
            Container(
              decoration: BoxDecoration(
                color: AppColors.darkBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.surfaceBg),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _ticketCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Ticket ID',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.tag_rounded, color: AppColors.textSecondary, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  Divider(height: 1, color: AppColors.surfaceBg),
                  TextField(
                    controller: _subtaskCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                    decoration: const InputDecoration(
                      hintText: 'Subtask / description',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon: Icon(Icons.subject_rounded, color: AppColors.textSecondary, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mediumBlue,
                  disabledBackgroundColor: AppColors.surfaceBg,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save Changes',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditTimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onPick;
  const _EditTimePicker({required this.label, required this.time, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final h = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour < 12 ? 'AM' : 'PM';
    final display = '$h:${time.minute.toString().padLeft(2, '0')} $period';

    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(display,
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ScoreChip extends StatelessWidget {
  final String label;
  final int score;
  const _ScoreChip({required this.label, required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ...List.generate(5, (i) => Icon(
          i < score ? Icons.circle_rounded : Icons.circle_outlined,
          size: 8,
          color: i < score ? AppColors.mediumBlue : AppColors.textSecondary,
        )),
      ],
    );
  }
}
