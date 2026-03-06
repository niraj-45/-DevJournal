import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/workspace_provider.dart';

class WorkspaceSetupScreen extends ConsumerStatefulWidget {
  const WorkspaceSetupScreen({super.key});

  @override
  ConsumerState<WorkspaceSetupScreen> createState() => _WorkspaceSetupScreenState();
}

class _WorkspaceSetupScreenState extends ConsumerState<WorkspaceSetupScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  Future<void> _createWorkspace() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      // Guard: use already-cached data — no extra round-trip
      final existing = ref.read(allWorkspacesProvider).valueOrNull ?? [];
      final alreadyExists = existing.any(
        (ws) => ws['name'].toString().toLowerCase() == name.toLowerCase(),
      );
      if (alreadyExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You already have a workspace with that name'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      final slug = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '-');

      // Use RPC to create workspace + add member in one server-side call
      // that bypasses the SELECT policy issue on the chained .select()
      final workspaceId = await Supabase.instance.client.rpc('create_workspace', params: {
        'workspace_name': name,
        'workspace_slug': '$slug-${DateTime.now().millisecondsSinceEpoch}',
      });

      if (workspaceId == null) throw Exception('Failed to create workspace');

      // Select the new workspace — this flips workspaceProvider from null
      // to the new workspace, which automatically shows TimerScreen.
      await ref.read(selectedWorkspaceIdProvider.notifier).select(workspaceId as String);
      ref.invalidate(allWorkspacesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Create your workspace',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('A workspace is your team. You can invite teammates later.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15, height: 1.5)),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Acme Engineering',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.cardBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _createWorkspace,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.mediumBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _isSaving ? 'Creating...' : 'Create Workspace',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}