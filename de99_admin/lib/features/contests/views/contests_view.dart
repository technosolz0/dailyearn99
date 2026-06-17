import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';
import 'package:de99_admin/features/contests/bloc/contests_cubit.dart';

class ContestsView extends StatefulWidget {
  const ContestsView({super.key});

  @override
  State<ContestsView> createState() => _ContestsViewState();
}

class _ContestsViewState extends State<ContestsView> {
  @override
  void initState() {
    super.initState();
    context.read<ContestsCubit>().fetchContests();
  }

  void _showCreateContestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (diagContext) => const CreateContestDialog(),
    );
  }

  void _confirmCompleteContest(BuildContext context, AdminContest contest) {
    showDialog(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Complete Payouts'),
        content: Text('Are you sure you want to force complete "${contest.title}" and distribute prize winnings to the leaderboard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(diagContext),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(diagContext);
              context.read<ContestsCubit>().completeContest(contest.id);
            },
            child: const Text('COMPLETE PAYOUT', style: TextStyle(color: AdminTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteContest(BuildContext context, AdminContest contest) {
    showDialog(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Delete Contest'),
        content: Text('Are you sure you want to permanently delete "${contest.title}"? This will delete all participant telemetry records.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(diagContext),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(diagContext);
              context.read<ContestsCubit>().deleteContest(contest.id);
            },
            child: const Text('DELETE', style: TextStyle(color: AdminTheme.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AdminTheme.primary,
        foregroundColor: AdminTheme.background,
        onPressed: () => _showCreateContestDialog(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<ContestsCubit>().fetchContests(),
        child: BlocBuilder<ContestsCubit, ContestsState>(
          builder: (context, state) {
            if (state is ContestsLoading) {
              return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
            } else if (state is ContestsError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 50, color: AdminTheme.error),
                      const SizedBox(height: 12),
                      Text(state.message, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.read<ContestsCubit>().fetchContests(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            } else if (state is ContestsLoaded) {
              final contests = state.contests;

              if (contests.isEmpty) {
                return const Center(
                  child: Text('No trivia contests configured.', style: TextStyle(color: AdminTheme.textMuted)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: contests.length,
                itemBuilder: (context, index) {
                  final c = contests[index];
                  final startStr = DateFormat.yMMMd().add_jm().format(c.startTime);
                  final progress = c.totalSlots > 0 ? c.joinedSlots / c.totalSlots : 0.0;
                  
                  Color statusColor = AdminTheme.warning;
                  if (c.status == 'ACTIVE') statusColor = AdminTheme.success;
                  if (c.status == 'COMPLETED') statusColor = AdminTheme.info;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  c.title,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor),
                                ),
                                child: Text(
                                  c.status,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Entry Fee', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                  Text(currencyFormatter.format(c.entryFee), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.primary)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Prize Pool', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                  Text(currencyFormatter.format(c.prizePool), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.success)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Slots Filled', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                  Text('${c.joinedSlots} / ${c.totalSlots}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Progress Bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: AdminTheme.borderColor,
                              valueColor: const AlwaysStoppedAnimation<Color>(AdminTheme.primary),
                              minHeight: 4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.access_time_outlined, size: 14, color: AdminTheme.textMuted),
                              const SizedBox(width: 4),
                              Text('Starts: $startStr', style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                            ],
                          ),
                          const Divider(color: AdminTheme.borderColor, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AdminTheme.error),
                                onPressed: () => _confirmDeleteContest(context, c),
                              ),
                              const Spacer(),
                              if (c.status != 'COMPLETED') ...[
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    backgroundColor: AdminTheme.success,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _confirmCompleteContest(context, c),
                                  child: const Text('Complete & Pay', style: TextStyle(fontSize: 12)),
                                ),
                              ] else ...[
                                const Text('Payout Finished', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted, fontStyle: FontStyle.italic)),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

class CreateContestDialog extends StatefulWidget {
  const CreateContestDialog({super.key});

  @override
  State<CreateContestDialog> createState() => _CreateContestDialogState();
}

class _CreateContestDialogState extends State<CreateContestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _feeController = TextEditingController();
  final _slotsController = TextEditingController();
  final _prizeController = TextEditingController();

  DateTime _startDate = DateTime.now().add(const Duration(minutes: 30));
  TimeOfDay _startTime = TimeOfDay.now();

  DateTime _endDate = DateTime.now().add(const Duration(hours: 2));
  TimeOfDay _endTime = TimeOfDay.now();

  @override
  void dispose() {
    _titleController.dispose();
    _feeController.dispose();
    _slotsController.dispose();
    _prizeController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime(bool isStart) async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );

    if (time == null) return;

    setState(() {
      if (isStart) {
        _startDate = date;
        _startTime = time;
      } else {
        _endDate = date;
        _endTime = time;
      }
    });
  }

  void _submit(BuildContext context) {
    if (_formKey.currentState!.validate()) {
      final start = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final end = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        _endTime.hour,
        _endTime.minute,
      );

      if (end.isBefore(start)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('End time must be after start time!'), backgroundColor: AdminTheme.error),
        );
        return;
      }

      context.read<ContestsCubit>().createContest(
            title: _titleController.text.trim(),
            entryFee: double.parse(_feeController.text),
            totalSlots: int.parse(_slotsController.text),
            prizePool: double.parse(_prizeController.text),
            startTime: start,
            endTime: end,
          );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startFormat = '${DateFormat.yMMMd().format(_startDate)} ${_startTime.format(context)}';
    final endFormat = '${DateFormat.yMMMd().format(_endDate)} ${_endTime.format(context)}';

    return AlertDialog(
      title: const Text('Create New Lobby'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Contest Title', prefixIcon: Icon(Icons.title)),
                validator: (val) => val == null || val.isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _feeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Entry Fee', prefixIcon: Icon(Icons.currency_rupee)),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Fee required';
                        if (double.tryParse(val) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _prizeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prize Pool', prefixIcon: Icon(Icons.emoji_events)),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Prize required';
                        if (double.tryParse(val) == null) return 'Invalid number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _slotsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Slots', prefixIcon: Icon(Icons.format_list_numbered)),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Slots required';
                  if (int.tryParse(val) == null) return 'Invalid integer';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Time pickers row
              ListTile(
                title: const Text('Start Date & Time', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                subtitle: Text(startFormat, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textMain)),
                trailing: const Icon(Icons.calendar_today, color: AdminTheme.primary),
                onTap: () => _pickDateTime(true),
              ),
              ListTile(
                title: const Text('End Date & Time', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                subtitle: Text(endFormat, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textMain)),
                trailing: const Icon(Icons.calendar_today, color: AdminTheme.primary),
                onTap: () => _pickDateTime(false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        TextButton(
          onPressed: () => _submit(context),
          child: const Text('CREATE LOBBY', style: TextStyle(color: AdminTheme.primary)),
        ),
      ],
    );
  }
}
