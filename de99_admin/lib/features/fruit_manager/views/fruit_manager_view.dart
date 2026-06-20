import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';

class FruitPrizeRule {
  int minRank;
  int maxRank;
  double prize;

  FruitPrizeRule({
    required this.minRank,
    required this.maxRank,
    required this.prize,
  });

  factory FruitPrizeRule.fromJson(Map<String, dynamic> json) {
    return FruitPrizeRule(
      minRank: json['min_rank'] ?? 1,
      maxRank: json['max_rank'] ?? 1,
      prize: (json['prize'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'min_rank': minRank,
        'max_rank': maxRank,
        'prize': prize,
      };
}

class FruitContest {
  final int id;
  final String title;
  final double entryFee;
  final int totalSlots;
  final int joinedSlots;
  final double prizePool;
  final int durationSeconds;
  final String seed;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final List<FruitPrizeRule> prizeRules;

  FruitContest({
    required this.id,
    required this.title,
    required this.entryFee,
    required this.totalSlots,
    required this.joinedSlots,
    required this.prizePool,
    required this.durationSeconds,
    required this.seed,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.prizeRules,
  });

  factory FruitContest.fromJson(Map<String, dynamic> json) {
    List<FruitPrizeRule> rules = [];
    final rawRules = json['prize_rules'];
    if (rawRules != null) {
      if (rawRules is List) {
        rules = rawRules.map((x) => FruitPrizeRule.fromJson(x)).toList();
      }
    }
    return FruitContest(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Fruit Contest',
      entryFee: (json['entry_fee'] ?? 0).toDouble(),
      totalSlots: json['total_slots'] ?? 0,
      joinedSlots: json['joined_slots'] ?? 0,
      prizePool: (json['prize_pool'] ?? 0).toDouble(),
      durationSeconds: json['duration_seconds'] ?? 60,
      seed: json['seed'] ?? '',
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      status: json['status'] ?? 'UPCOMING',
      prizeRules: rules,
    );
  }
}

class FruitManagerView extends StatefulWidget {
  const FruitManagerView({super.key});

  @override
  State<FruitManagerView> createState() => _FruitManagerViewState();
}

class _FruitManagerViewState extends State<FruitManagerView> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  bool _isLoading = false;
  String? _error;

  bool _maintenanceVal = false;
  List<FruitContest> _contests = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final maintenanceRes = await _apiClient.dio.get('/admin/fruit-slicing/maintenance');
      final contestsRes = await _apiClient.dio.get('/fruit-game/contests');

      setState(() {
        _maintenanceVal = maintenanceRes.data['maintenance_mode'] as bool? ?? false;
        _contests = (contestsRes.data as List).map((x) => FruitContest.fromJson(x)).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.response?.data['detail'] ?? e.message ?? 'Failed to load Fruit tournaments';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleMaintenance(bool val) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await _apiClient.dio.post('/admin/fruit-slicing/maintenance', queryParameters: {'enabled': val});
      setState(() {
        _maintenanceVal = res.data['maintenance_mode'] as bool? ?? val;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_maintenanceVal ? 'Fruit tournaments are locked.' : 'Fruit tournaments are active.'),
          backgroundColor: _maintenanceVal ? AdminTheme.error : AdminTheme.success,
        ),
      );
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to update maintenance lockout'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _completeContest(FruitContest c) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Confirm Completion'),
        content: Text('Are you sure you want to end "${c.title}" and award prizes to the top players?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(diagContext, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(diagContext, true),
            child: const Text('COMPLETE PAYOUT', style: TextStyle(color: AdminTheme.primary)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.post('/admin/fruit-slicing/contests/${c.id}/complete');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prizes paid out successfully!'), backgroundColor: AdminTheme.success),
      );
      await _loadData();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to complete tournament'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteContest(FruitContest c) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to permanently delete "${c.title}"? This will delete all matching scoreboard data!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(diagContext, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(diagContext, true),
            child: const Text('DELETE', style: TextStyle(color: AdminTheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.delete('/admin/fruit-slicing/contests/${c.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fruit tournament deleted successfully.'), backgroundColor: AdminTheme.success),
      );
      await _loadData();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to delete tournament'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLaunchModal() {
    showDialog(
      context: context,
      builder: (modalContext) => LaunchFruitContestDialog(
        onSubmit: (payload) async {
          setState(() {
            _isLoading = true;
          });
          try {
            await _apiClient.dio.post('/admin/fruit-slicing/contests', data: payload);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Fruit slicing tournament launched successfully!'), backgroundColor: AdminTheme.success),
            );
            await _loadData();
          } on DioException catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to launch tournament'), backgroundColor: AdminTheme.error),
            );
            setState(() {
              _isLoading = false;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    if (_isLoading && _contests.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: AdminTheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: AdminTheme.primary,
        foregroundColor: AdminTheme.background,
        onPressed: _showLaunchModal,
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Lockout switch card
              Card(
                child: SwitchListTile(
                  activeColor: AdminTheme.error,
                  title: const Text('Fruit Slicing Maintenance Lock', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Lock gameplay access for players instantly'),
                  value: _maintenanceVal,
                  onChanged: _toggleMaintenance,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Fruit Slicing Tournaments',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
              ),
              const SizedBox(height: 12),

              if (_contests.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No active tournaments found.', style: TextStyle(color: AdminTheme.textMuted)),
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _contests.length,
                  itemBuilder: (context, index) {
                    final c = _contests[index];
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
                                Text('Starts: $startStr | Duration: ${c.durationSeconds}s', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                              ],
                            ),
                            if (c.prizeRules.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              const Text('Prize Payout Structure:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AdminTheme.textMuted)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: c.prizeRules.map((rule) {
                                  final rankStr = rule.minRank == rule.maxRank ? 'Rank ${rule.minRank}' : 'Rank ${rule.minRank}-${rule.maxRank}';
                                  return Chip(
                                    padding: EdgeInsets.zero,
                                    labelPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: -2),
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: AdminTheme.surface,
                                    label: Text('$rankStr: ₹${rule.prize.toStringAsFixed(0)}', style: const TextStyle(fontSize: 10)),
                                  );
                                }).toList(),
                              ),
                            ],
                            const Divider(color: AdminTheme.borderColor, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AdminTheme.error),
                                  onPressed: () => _deleteContest(c),
                                ),
                                const Spacer(),
                                if (c.status != 'COMPLETED') ...[
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                      backgroundColor: AdminTheme.success,
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () => _completeContest(c),
                                    child: const Text('Complete & Pay', style: TextStyle(fontSize: 12)),
                                  ),
                                ] else ...[
                                  const Text('Payout Completed', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted, fontStyle: FontStyle.italic)),
                                ]
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class LaunchFruitContestDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const LaunchFruitContestDialog({super.key, required this.onSubmit});

  @override
  State<LaunchFruitContestDialog> createState() => _LaunchFruitContestDialogState();
}

class _LaunchFruitContestDialogState extends State<LaunchFruitContestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _feeController = TextEditingController(text: '10');
  final _slotsController = TextEditingController(text: '100');
  final _poolController = TextEditingController(text: '750');
  final _durationController = TextEditingController(text: '60');

  DateTime _startDate = DateTime.now().add(const Duration(minutes: 10));
  TimeOfDay _startTime = TimeOfDay.now();

  final List<FruitPrizeRule> _prizeRules = [];

  void _addPrizeRule() {
    int nextMin = 1;
    if (_prizeRules.isNotEmpty) {
      nextMin = _prizeRules.last.maxRank + 1;
    }
    setState(() {
      _prizeRules.add(FruitPrizeRule(minRank: nextMin, maxRank: nextMin, prize: 50.0));
    });
  }

  void _removePrizeRule(int index) {
    setState(() {
      _prizeRules.removeAt(index);
    });
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time == null) return;

    setState(() {
      _startDate = date;
      _startTime = time;
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final start = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final payload = {
        'title': _titleController.text.trim(),
        'entry_fee': double.parse(_feeController.text),
        'total_slots': int.parse(_slotsController.text),
        'prize_pool': double.parse(_poolController.text),
        'duration_seconds': int.parse(_durationController.text),
        'start_time': start.toUtc().toIso8601String(),
        'end_time': null,
        'prize_rules': _prizeRules.map((r) => r.toJson()).toList(),
      };

      widget.onSubmit(payload);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startFormat = '${DateFormat.yMMMd().format(_startDate)} ${_startTime.format(context)}';

    return AlertDialog(
      title: const Text('Launch Fruit Slicing Tournament'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tournament Title'),
                validator: (val) => val == null || val.isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _feeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Entry Fee (INR)'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _poolController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prize Pool'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _slotsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Total Slots'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration (Sec)'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date & Time', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                subtitle: Text(startFormat, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textMain)),
                trailing: const Icon(Icons.calendar_today, color: AdminTheme.primary),
                onTap: _pickDateTime,
              ),
              const Divider(color: AdminTheme.borderColor, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rank Prize Rules', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(onPressed: _addPrizeRule, child: const Text('+ ADD RULE')),
                ],
              ),
              const SizedBox(height: 8),
              if (_prizeRules.isEmpty)
                const Text('Default distribution will apply if no rules are added.', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted, fontStyle: FontStyle.italic))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _prizeRules.length,
                  itemBuilder: (context, idx) {
                    final rule = _prizeRules[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: rule.minRank.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Min Rank'),
                              onChanged: (val) => rule.minRank = int.tryParse(val) ?? 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('to'),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextFormField(
                              initialValue: rule.maxRank.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Max Rank'),
                              onChanged: (val) => rule.maxRank = int.tryParse(val) ?? 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextFormField(
                              initialValue: rule.prize.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Prize (₹)'),
                              onChanged: (val) => rule.prize = double.tryParse(val) ?? 0.0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AdminTheme.error, size: 18),
                            onPressed: () => _removePrizeRule(idx),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        TextButton(onPressed: _submit, child: const Text('LAUNCH TOURNAMENT', style: TextStyle(color: AdminTheme.primary))),
      ],
    );
  }
}
