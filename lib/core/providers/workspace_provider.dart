import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── All workspaces the user belongs to ──────────────────────────────────────
final allWorkspacesProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return [];

  final response = await Supabase.instance.client
      .from('workspace_members')
      .select('workspace_id, workspaces(id, name, slug)')
      .eq('user_id', user.id);

  return (response as List)
      .map((row) => row['workspaces'] as Map<String, dynamic>?)
      .whereType<Map<String, dynamic>>()
      .toList();
});

// ── Selected workspace ID (persisted to SharedPreferences) ──────────────────
class WorkspaceSelectionNotifier extends StateNotifier<String?> {
  WorkspaceSelectionNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('selected_workspace_id');
    if (id != null) state = id;
  }

  Future<void> select(String id) async {
    state = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_workspace_id', id);
  }

  /// Clears the persisted selection. Call this on logout so the next user
  /// doesn't inherit another user's workspace.
  Future<void> clear() async {
    state = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_workspace_id');
  }
}

final selectedWorkspaceIdProvider =
    StateNotifierProvider<WorkspaceSelectionNotifier, String?>(
        (ref) => WorkspaceSelectionNotifier());

// ── Active workspace (derived) ───────────────────────────────────────────────
final workspaceProvider = Provider<AsyncValue<Map<String, dynamic>?>>((ref) {
  final allAsync = ref.watch(allWorkspacesProvider);
  final selectedId = ref.watch(selectedWorkspaceIdProvider);

  return allAsync.when(
    loading: () => const AsyncLoading(),
    error: (e, s) => AsyncError(e, s),
    data: (workspaces) {
      if (workspaces.isEmpty) return const AsyncData(null);
      // Empty string means the user explicitly tapped "New Workspace" —
      // return null so WorkspaceSetupScreen is displayed.
      if (selectedId != null && selectedId.isEmpty) return const AsyncData(null);
      if (selectedId != null) {
        final match = workspaces.firstWhere(
          (w) => w['id'] == selectedId,
          orElse: () => workspaces.first,
        );
        return AsyncData(match);
      }
      return AsyncData(workspaces.first);
    },
  );
});

// ── Delete a workspace with full cascade ─────────────────────────────────────
// Deletes all data owned by the current user in that workspace, then removes
// the workspace itself.  If the workspace has other members the final workspace
// row delete will be blocked by RLS, which is intentional.
Future<void> deleteWorkspace(String workspaceId, WidgetRef ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;
  if (user == null) return;

  // 1. Delete mood_logs for this user's sessions in this workspace
  final sessionRows = await client
      .from('sessions')
      .select('id')
      .eq('workspace_id', workspaceId)
      .eq('user_id', user.id);

  final sessionIds = (sessionRows as List).map((r) => r['id'] as String).toList();

  // Run all deletes in parallel — mood_logs, sessions, and workspace_members
  // are independent of each other once we have the session IDs.
  await Future.wait([
    if (sessionIds.isNotEmpty)
      client.from('mood_logs').delete().inFilter('session_id', sessionIds),
    if (sessionIds.isNotEmpty)
      client.from('sessions').delete().inFilter('id', sessionIds),
    client
        .from('workspace_members')
        .delete()
        .eq('workspace_id', workspaceId)
        .eq('user_id', user.id),
  ]);

  // Try to delete the workspace row itself (succeeds only if no other members)
  try {
    await client.from('workspaces').delete().eq('id', workspaceId);
  } catch (_) {
    // Other members still exist — workspace row stays, which is correct.
  }

  // 4. If the deleted workspace was selected, fall back to first available
  final selectedId = ref.read(selectedWorkspaceIdProvider);
  if (selectedId == workspaceId) {
    await ref.read(selectedWorkspaceIdProvider.notifier).clear();
  }

  ref.invalidate(allWorkspacesProvider);
}