import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/timer_provider.dart';
import '../../core/providers/workspace_provider.dart';
import '../../core/providers/work_hours_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../auth/workspace_setup_screen.dart';
import 'mood_sheet.dart';

class TimerScreen extends ConsumerStatefulWidget {
  const TimerScreen({super.key});

  @override
  ConsumerState<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends ConsumerState<TimerScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timerState = ref.watch(timerProvider);
    final workspaceAsync = ref.watch(workspaceProvider);

    return workspaceAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.mediumBlue)),
      ),
      error: (e, stack) => Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Something went wrong',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => ref.invalidate(allWorkspacesProvider),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.mediumBlue),
                  child: const Text('Retry', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (workspace) {
        if (workspace == null) return const WorkspaceSetupScreen();

        return Scaffold(
          backgroundColor: AppColors.darkBg,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => _showWorkspaceSwitcher(context, ref),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('DevJournal',
                                  style: TextStyle(
                                    color: AppColors.mediumBlue,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(workspace['name'],
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.unfold_more_rounded,
                                        color: AppColors.textSecondary, size: 18),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => context.push('/sessions'),
                            icon: const Icon(Icons.list_rounded, color: AppColors.textSecondary),
                          ),
                          IconButton(
                            onPressed: () => context.push('/standup'),
                            icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.textSecondary),
                          ),
                          IconButton(
                            onPressed: () async {
                              await ref
                                  .read(selectedWorkspaceIdProvider.notifier)
                                  .clear();
                              ref.invalidate(allWorkspacesProvider);
                              await Supabase.instance.client.auth.signOut();
                              if (context.mounted) context.go('/login');
                            },
                            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
                          ),
                        ],
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Work hours bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _WorkHoursBar(
                    timerElapsedSeconds: timerState.isRunning ? timerState.elapsedSeconds : 0,
                    onTap: () => _showWorkHoursSettings(context, ref),
                  ),
                ),

                const SizedBox(height: 12),

                // Page indicator dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _PageDot(active: _currentPage == 0, label: 'Live'),
                    const SizedBox(width: 8),
                    _PageDot(active: _currentPage == 1, label: 'Manual'),
                  ],
                ),

                const SizedBox(height: 8),

                // PageView: Live timer (0) ←→ Manual entry (1)
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    // Block swiping while timer is running to prevent accidental page changes
                    physics: timerState.isRunning
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    children: [
                      // ─── Page 0: Live Timer ──────────────────────────────
                      _LiveTimerPage(workspace: workspace),

                      // ─── Page 1: Manual Entry ────────────────────────────
                      _ManualEntryPage(workspaceId: workspace['id'] as String),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showWorkspaceSwitcher(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const _WorkspaceSwitcherSheet(),
    );
  }

  void _showWorkHoursSettings(BuildContext context, WidgetRef ref) {
    final hours = ref.read(workHoursProvider);
    TimeOfDay start = hours.start;
    TimeOfDay end = hours.end;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
              24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Work Hours',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Used to calculate untracked time in your work day.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _TimePicker(
                      label: 'Start',
                      time: start,
                      onPick: (t) async {
                        final picked = await showTimePicker(
                            context: context, initialTime: start);
                        if (picked != null) setState(() => start = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.arrow_forward_rounded,
                      color: AppColors.textSecondary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _TimePicker(
                      label: 'End',
                      time: end,
                      onPick: (t) async {
                        final picked = await showTimePicker(
                            context: context, initialTime: end);
                        if (picked != null) setState(() => end = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(workHoursProvider.notifier).setHours(start, end);
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mediumBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Save',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page Dot indicator ────────────────────────────────────────────────────────
class _PageDot extends StatelessWidget {
  final bool active;
  final String label;
  const _PageDot({required this.active, required this.label});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? AppColors.mediumBlue.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: active ? AppColors.mediumBlue : AppColors.textSecondary,
          fontSize: 12,
          fontWeight: active ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

// ── Page 0: Live Timer ────────────────────────────────────────────────────────
class _LiveTimerPage extends ConsumerWidget {
  final Map<String, dynamic> workspace;
  const _LiveTimerPage({required this.workspace});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timerState = ref.watch(timerProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const Spacer(flex: 1),

                  // Timer display
                  Center(
                    child: Column(
                      children: [
                        Text(
                          timerState.formattedTime,
                          style: TextStyle(
                            color: timerState.isRunning
                                ? AppColors.mediumBlue
                                : AppColors.textSecondary,
                            fontSize: 72,
                            fontWeight: FontWeight.w200,
                            letterSpacing: -2,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          timerState.isRunning ? 'Session running' : 'Ready to track',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Ticket + Subtask input
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: timerState.isRunning
                            ? AppColors.mediumBlue.withOpacity(0.4)
                            : AppColors.surfaceBg,
                      ),
                    ),
                    child: Column(
                      children: [
                        TextField(
                          onChanged: (val) => ref.read(timerProvider.notifier).setTicket(val),
                          enabled: !timerState.isRunning,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                          decoration: const InputDecoration(
                            hintText: 'Ticket ID  (e.g. ENG-42)',
                            hintStyle: TextStyle(color: AppColors.textSecondary),
                            prefixIcon: Icon(Icons.tag_rounded, color: AppColors.textSecondary, size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.surfaceBg),
                        TextField(
                          onChanged: (val) => ref.read(timerProvider.notifier).setSubtask(val),
                          enabled: !timerState.isRunning,
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

                  // Out-of-work-hours warning
                  _OutOfHoursChip(),

                  const Spacer(flex: 1),

                  // Start / Stop button
                  Center(
                    child: Builder(builder: (innerCtx) {
                      final hasTicket =
                          timerState.ticketInput?.trim().isNotEmpty == true;
                      final hasSubtask =
                          timerState.subtaskInput?.trim().isNotEmpty == true;
                      final canStart = timerState.isRunning || (hasTicket && hasSubtask);
                      final activeColor = timerState.isRunning
                          ? AppColors.error
                          : AppColors.mediumBlue;
                      final dimColor = AppColors.textSecondary;
                      final btnColor = canStart ? activeColor : dimColor;

                      return GestureDetector(
                        onTap: () async {
                          final notifier = ref.read(timerProvider.notifier);
                          if (timerState.isRunning) {
                            final sessionId = await notifier.stopTimer();
                            if (sessionId != null && innerCtx.mounted) {
                              ref.invalidate(todaySessionsProvider);
                              showModalBottomSheet(
                                context: innerCtx,
                                backgroundColor: AppColors.cardBg,
                                isScrollControlled: true,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                ),
                                builder: (_) => MoodSheet(sessionId: sessionId),
                              );
                            }
                          } else {
                            if (!hasTicket || !hasSubtask) {
                              ScaffoldMessenger.of(innerCtx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    !hasTicket
                                        ? 'Enter a Ticket ID before starting'
                                        : 'Enter a subtask / description before starting',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            await notifier.startTimer(workspace['id']);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: btnColor.withOpacity(0.15),
                            border: Border.all(
                              color: btnColor,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            timerState.isRunning
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                            color: btnColor,
                            size: 52,
                          ),
                        ),
                      );
                    }),
                  ),

                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Page 1: Manual Entry ──────────────────────────────────────────────────────
class _ManualEntryPage extends ConsumerStatefulWidget {
  final String workspaceId;
  const _ManualEntryPage({required this.workspaceId});

  @override
  ConsumerState<_ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends ConsumerState<_ManualEntryPage> {
  final _ticketCtrl = TextEditingController();
  final _subtaskCtrl = TextEditingController();
  TimeOfDay _startTime = TimeOfDay.now();
  TimeOfDay _endTime = TimeOfDay.now();
  bool _saving = false;

  @override
  void dispose() {
    _ticketCtrl.dispose();
    _subtaskCtrl.dispose();
    super.dispose();
  }

  DateTime _todayAt(TimeOfDay t) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, t.hour, t.minute);
  }

  String _fmtDuration(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  Future<void> _submit() async {
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

    final start = _todayAt(_startTime);
    var end = _todayAt(_endTime);
    // If end <= start, assume next day
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    setState(() => _saving = true);
    try {
      await createManualSession(
        workspaceId: widget.workspaceId,
        start: start,
        end: end,
        ticketId: ticket,
        notes: subtask,
        ref: ref,
      );
      if (mounted) {
        _ticketCtrl.clear();
        _subtaskCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session created'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
    final startDt = _todayAt(_startTime);
    var endDt = _todayAt(_endTime);
    if (!endDt.isAfter(startDt)) endDt = endDt.add(const Duration(days: 1));
    final durationMins = endDt.difference(startDt).inMinutes;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text('Log a past session',
              style: TextStyle(
                  color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Manually enter a session that already happened.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),

          const SizedBox(height: 24),

          // Time pickers
          Row(
            children: [
              Expanded(
                child: _TimePicker(
                  label: 'Start',
                  time: _startTime,
                  onPick: (_) async {
                    final picked = await showTimePicker(
                        context: context, initialTime: _startTime);
                    if (picked != null) setState(() => _startTime = picked);
                  },
                ),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: _TimePicker(
                  label: 'End',
                  time: _endTime,
                  onPick: (_) async {
                    final picked = await showTimePicker(
                        context: context, initialTime: _endTime);
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
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceBg),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _ticketCtrl,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
                  decoration: const InputDecoration(
                    hintText: 'Ticket ID  (e.g. ENG-42)',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                    prefixIcon: Icon(Icons.tag_rounded, color: AppColors.textSecondary, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
                const Divider(height: 1, color: AppColors.surfaceBg),
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

          // Submit
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mediumBlue,
                disabledBackgroundColor: AppColors.surfaceBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Session',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Workspace Switcher Sheet ──────────────────────────────────────────────────
class _WorkspaceSwitcherSheet extends ConsumerStatefulWidget {
  const _WorkspaceSwitcherSheet();

  @override
  ConsumerState<_WorkspaceSwitcherSheet> createState() =>
      _WorkspaceSwitcherSheetState();
}

class _WorkspaceSwitcherSheetState
    extends ConsumerState<_WorkspaceSwitcherSheet> {
  String? _deletingId;

  Future<void> _confirmDelete(
      BuildContext context, Map<String, dynamic> ws) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Delete workspace?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'All sessions and mood logs for "${ws['name']}" will be permanently deleted.',
          style: const TextStyle(color: AppColors.textSecondary),
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

    if (confirmed != true || !mounted) return;

    setState(() => _deletingId = ws['id'] as String);
    try {
      await deleteWorkspace(ws['id'] as String, ref);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Delete failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(allWorkspacesProvider);
    final selectedId = ref.watch(selectedWorkspaceIdProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Switch Workspace',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          allAsync.when(
            loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.mediumBlue)),
            error: (e, _) => Text(e.toString(),
                style: const TextStyle(color: AppColors.error)),
            data: (workspaces) {
              if (workspaces.isEmpty) {
                Navigator.pop(context);
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  ...workspaces.map((ws) {
                    final isSelected = ws['id'] == selectedId ||
                        (selectedId == null && ws == workspaces.first);
                    final isDeleting = _deletingId == ws['id'];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.mediumBlue.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.workspaces_rounded,
                            color: AppColors.mediumBlue, size: 20),
                      ),
                      title: Text(ws['name'],
                          style: TextStyle(
                              color: isSelected
                                  ? AppColors.mediumBlue
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal)),
                      trailing: isDeleting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.error))
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  const Icon(Icons.check_rounded,
                                      color: AppColors.mediumBlue),
                                // Disallow deleting the currently active workspace —
                                // user must switch away first.
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded,
                                      color: isSelected
                                          ? AppColors.surfaceBg
                                          : AppColors.textSecondary,
                                      size: 20),
                                  onPressed: isSelected
                                      ? () {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                            content: Text(
                                                'Switch to another workspace before deleting this one'),
                                            behavior:
                                                SnackBarBehavior.floating,
                                          ));
                                        }
                                      : () => _confirmDelete(context, ws),
                                  tooltip: isSelected
                                      ? 'Switch workspace first'
                                      : 'Delete workspace',
                                ),
                              ],
                            ),
                      onTap: isDeleting
                          ? null
                          : () {
                              ref
                                  .read(selectedWorkspaceIdProvider.notifier)
                                  .select(ws['id'] as String);
                              Navigator.pop(context);
                            },
                    );
                  }),
                  const Divider(color: AppColors.surfaceBg),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_rounded,
                          color: AppColors.textSecondary, size: 20),
                    ),
                    title: const Text('New Workspace',
                        style: TextStyle(color: AppColors.textSecondary)),
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(selectedWorkspaceIdProvider.notifier).select('');
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Work Hours Progress Bar ───────────────────────────────────────────────────
class _WorkHoursBar extends ConsumerWidget {
  final int timerElapsedSeconds;
  final VoidCallback onTap;
  const _WorkHoursBar({required this.timerElapsedSeconds, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = ref.watch(workHoursProvider);
    final sessionsAsync = ref.watch(todaySessionsProvider);

    final totalWorkSeconds = hours.totalMinutes * 60;
    if (totalWorkSeconds <= 0) return const SizedBox.shrink();

    final trackedSeconds =
        sessionsAsync.maybeWhen(
          data: (sessions) => sessions.fold<int>(
              0, (s, e) => s + (e.session.durationSeconds ?? 0)),
          orElse: () => 0,
        ) + timerElapsedSeconds;

    final progress = (trackedSeconds / totalWorkSeconds).clamp(0.0, 1.0);
    final untrackedSeconds =
        (totalWorkSeconds - trackedSeconds).clamp(0, totalWorkSeconds);

    String _fmtTime(int seconds) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      return h > 0 ? '${h}h ${m}m' : '${m}m';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${hours.startLabel} – ${hours.endLabel}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                ),
                Row(
                  children: [
                    Text(
                      '${_fmtTime(untrackedSeconds)} untracked',
                      style: TextStyle(
                        color: untrackedSeconds > 0
                            ? AppColors.textSecondary
                            : AppColors.success,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.tune_rounded,
                        color: AppColors.textSecondary, size: 14),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceBg,
                valueColor:
                    AlwaysStoppedAnimation<Color>(AppColors.mediumBlue),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_fmtTime(trackedSeconds)} tracked of ${_fmtTime(totalWorkSeconds)} work day',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Time picker tile ───────────────────────────────────────────────────────────
class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final Function(TimeOfDay) onPick;
  const _TimePicker(
      {required this.label, required this.time, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final h = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final period = time.hour < 12 ? 'AM' : 'PM';
    final display = '$h:${time.minute.toString().padLeft(2, '0')} $period';

    return GestureDetector(
      onTap: () => onPick(time),
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
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(display,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Out-of-work-hours warning chip ────────────────────────────────────────────
class _OutOfHoursChip extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours = ref.watch(workHoursProvider);
    final now = TimeOfDay.now();
    final nowMins = now.hour * 60 + now.minute;
    final startMins = hours.startHour * 60 + hours.startMinute;
    final endMins = hours.endHour * 60 + hours.endMinute;

    bool outsideHours;
    if (endMins > startMins) {
      // Normal schedule (e.g. 9 AM – 6 PM)
      outsideHours = nowMins < startMins || nowMins >= endMins;
    } else {
      // Midnight-crossing schedule (e.g. 6 PM – 12:30 AM)
      outsideHours = nowMins >= endMins && nowMins < startMins;
    }

    if (!outsideHours) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule_rounded, color: AppColors.warning, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Outside your work hours (${hours.startLabel} – ${hours.endLabel})',
                style: const TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}