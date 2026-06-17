import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';
import 'package:de99_admin/core/utils/notification_log.dart';
import 'package:de99_admin/features/notifications/bloc/notifications_cubit.dart';

class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _userIdController = TextEditingController();
  
  String _audienceType = 'all'; // 'all' or 'user'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();

      if (_audienceType == 'all') {
        context.read<NotificationsCubit>().sendBroadcast(title: title, body: body);
      } else {
        final userId = int.parse(_userIdController.text.trim());
        context.read<NotificationsCubit>().sendDirect(userId: userId, title: title, body: body);
      }
    }
  }

  Widget _buildPushForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'FCM Push Broadcaster',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.primary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Transmit cloud notifications directly to client devices.',
              style: TextStyle(fontSize: 13, color: AdminTheme.textMuted),
            ),
            const SizedBox(height: 24),
            
            // Title Input
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Notification Title',
                prefixIcon: Icon(Icons.title),
                hintText: 'e.g. 🎁 Weekly Bonus!',
              ),
              validator: (val) => val == null || val.isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            
            // Body Input
            TextFormField(
              controller: _bodyController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message Body',
                prefixIcon: Icon(Icons.message_outlined),
                hintText: 'Type your message details here...',
              ),
              validator: (val) => val == null || val.isEmpty ? 'Message body is required' : null,
            ),
            const SizedBox(height: 16),
            
            // Audience Type Dropdown
            DropdownButtonFormField<String>(
              value: _audienceType,
              decoration: const InputDecoration(
                labelText: 'Target Audience',
                prefixIcon: Icon(Icons.group_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Broadcast to All Users')),
                DropdownMenuItem(value: 'user', child: Text('Target Specific User ID')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _audienceType = val;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Conditional User ID Input
            if (_audienceType == 'user') ...[
              TextFormField(
                controller: _userIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'User ID',
                  prefixIcon: Icon(Icons.person_pin_outlined),
                  hintText: 'e.g. 5',
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'User ID is required';
                  if (int.tryParse(val) == null) return 'Invalid User ID';
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            
            const SizedBox(height: 16),
            
            // Submit Button
            BlocConsumer<NotificationsCubit, NotificationsState>(
              listener: (context, state) {
                if (state is NotificationsSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message), backgroundColor: AdminTheme.success),
                  );
                  _titleController.clear();
                  _bodyController.clear();
                  _userIdController.clear();
                  context.read<NotificationsCubit>().reset();
                } else if (state is NotificationsError) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.message), backgroundColor: AdminTheme.error),
                  );
                  context.read<NotificationsCubit>().reset();
                }
              },
              builder: (context, state) {
                if (state is NotificationsSending) {
                  return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
                }
                return ElevatedButton(
                  onPressed: _submit,
                  child: const Text('TRANSMIT NOTIFICATION'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsView() {
    return StreamBuilder<List<AdminNotificationItem>>(
      stream: NotificationLog.stream,
      initialData: NotificationLog.logs,
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];

        if (logs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none_outlined, size: 50, color: AdminTheme.textMuted),
                  SizedBox(height: 12),
                  Text(
                    'No real-time notification alerts received yet.',
                    style: TextStyle(color: AdminTheme.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Live Alerts Log (${logs.length})',
                    style: const TextStyle(fontSize: 13, color: AdminTheme.textMuted, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: AdminTheme.error, padding: EdgeInsets.zero),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                    label: const Text('Clear All', style: TextStyle(fontSize: 12)),
                    onPressed: () {
                      NotificationLog.clearLogs();
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final log = logs[index];
                  final timeStr = DateFormat.Hm().format(log.receivedAt);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: AdminTheme.surfaceDark,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              log.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AdminTheme.primary),
                            ),
                          ),
                          Text(
                            timeStr,
                            style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(log.body, style: const TextStyle(color: AdminTheme.textMain, fontSize: 13)),
                            if (log.data.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AdminTheme.surface,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AdminTheme.borderColor),
                                ),
                                child: Text(
                                  log.data.toString(),
                                  style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: AdminTheme.textMuted),
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: AdminTheme.surfaceDark,
          child: TabBar(
            controller: _tabController,
            indicatorColor: AdminTheme.primary,
            labelColor: AdminTheme.primary,
            unselectedLabelColor: AdminTheme.textMuted,
            tabs: const [
              Tab(icon: Icon(Icons.send), text: 'Send Pushes'),
              Tab(icon: Icon(Icons.speaker_notes), text: 'Console Logs'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPushForm(),
          _buildLogsView(),
        ],
      ),
    );
  }
}
