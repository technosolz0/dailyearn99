import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';

class LotteryDraw {
  final int id;
  final String title;
  final double ticketPrice;
  final double prizePool;
  final int maxTickets;
  final int joinedTickets;
  final double winPercentage;
  final String? forcedWinningNumber;
  final DateTime drawTime;
  final String status;
  final String? winningNumber;

  LotteryDraw({
    required this.id,
    required this.title,
    required this.ticketPrice,
    required this.prizePool,
    required this.maxTickets,
    required this.joinedTickets,
    required this.winPercentage,
    this.forcedWinningNumber,
    required this.drawTime,
    required this.status,
    this.winningNumber,
  });

  factory LotteryDraw.fromJson(Map<String, dynamic> json) {
    return LotteryDraw(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Lucky Draw',
      ticketPrice: (json['ticket_price'] ?? 0).toDouble(),
      prizePool: (json['prize_pool'] ?? 0).toDouble(),
      maxTickets: json['max_tickets'] ?? 1000,
      joinedTickets: json['joined_tickets'] ?? 0,
      winPercentage: (json['win_percentage'] ?? 0).toDouble(),
      forcedWinningNumber: json['forced_winning_number']?.toString(),
      drawTime: DateTime.parse(json['draw_time']),
      status: json['status'] ?? 'OPEN',
      winningNumber: json['winning_number']?.toString(),
    );
  }
}

class LotteryEngineView extends StatefulWidget {
  const LotteryEngineView({super.key});

  @override
  State<LotteryEngineView> createState() => _LotteryEngineViewState();
}

class _LotteryEngineViewState extends State<LotteryEngineView> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  bool _isLoading = false;
  String? _error;

  List<LotteryDraw> _draws = [];

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
      final res = await _apiClient.dio.get('/admin/lottery/draws');
      setState(() {
        _draws = (res.data as List).map((x) => LotteryDraw.fromJson(x)).toList();
        _isLoading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.response?.data['detail'] ?? e.message ?? 'Failed to load Lottery draws schedule';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _executeDraw(LotteryDraw draw) async {
    final TextEditingController forceNumController = TextEditingController();
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Execute Draw Winner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to run the draw for "${draw.title}"? Winnings will be credited immediately to winners.'),
            const SizedBox(height: 16),
            TextField(
              controller: forceNumController,
              decoration: const InputDecoration(
                labelText: 'Force Winner Ticket (Optional)',
                hintText: 'Leave empty for random/probability win',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(diagContext, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(diagContext, true),
            child: const Text('DRAW WINNER', style: TextStyle(color: AdminTheme.primary)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    final forcedText = forceNumController.text.trim();
    final Map<String, dynamic> qParams = {};
    if (forcedText.isNotEmpty) {
      qParams['forced_number'] = forcedText;
    }

    try {
      final response = await _apiClient.dio.post('/admin/lottery/draws/${draw.id}/draw', queryParameters: qParams);
      final data = response.data;
      
      final winningTicket = data['winning_ticket']?.toString() ?? '-';
      final prizeAmount = data['prize_awarded'] ?? 0.0;
      final winnerId = data['winner_user_id'];

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(winnerId != null
              ? 'Draw complete! Ticket #$winningTicket wins ₹$prizeAmount.'
              : 'Draw complete! No matching winning ticket (#$winningTicket).'),
          backgroundColor: AdminTheme.success,
        ),
      );
      await _loadData();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to execute lucky draw'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelDraw(LotteryDraw draw) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Cancel Draw & Refund'),
        content: Text('Are you sure you want to cancel "${draw.title}"? This issues full wallet refunds to all ticket buyers instantly!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(diagContext, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(diagContext, true),
            child: const Text('REFUND & CANCEL', style: TextStyle(color: AdminTheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.delete('/admin/lottery/draws/${draw.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lottery draw has been cancelled and tickets refunded.'), backgroundColor: AdminTheme.success),
      );
      await _loadData();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to cancel draw'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showLaunchModal() {
    showDialog(
      context: context,
      builder: (modalContext) => LaunchLotteryDialog(
        onSubmit: (payload) async {
          setState(() {
            _isLoading = true;
          });
          try {
            await _apiClient.dio.post('/admin/lottery/draws', data: payload);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lucky draw scheduled successfully!'), backgroundColor: AdminTheme.success),
            );
            await _loadData();
          } on DioException catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to schedule lucky draw'), backgroundColor: AdminTheme.error),
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

    if (_isLoading && _draws.isEmpty) {
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
              const Text(
                'Lottery Engine Draws Schedule',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
              ),
              const SizedBox(height: 12),

              if (_draws.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text('No lucky draws scheduled yet.', style: TextStyle(color: AdminTheme.textMuted)),
                  ),
                ),
              ] else ...[
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _draws.length,
                  itemBuilder: (context, index) {
                    final d = _draws[index];
                    final drawTimeStr = DateFormat.yMMMd().add_jm().format(d.drawTime);
                    final progress = d.maxTickets > 0 ? d.joinedTickets / d.maxTickets : 0.0;
                    
                    Color statusColor = AdminTheme.success;
                    if (d.status == 'COMPLETED') statusColor = AdminTheme.textMuted;
                    if (d.status == 'CANCELLED') statusColor = AdminTheme.error;

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
                                    d.title,
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
                                    d.status,
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
                                    const Text('Ticket Price', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                    Text(currencyFormatter.format(d.ticketPrice), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.primary)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Prize Pool', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                    Text(currencyFormatter.format(d.prizePool), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.success)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Tickets Sold', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                                    Text('${d.joinedTickets} / ${d.maxTickets}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                            _buildInfoRow('Win Ratio Config', '${d.winPercentage.toStringAsFixed(0)}% chance'),
                            _buildInfoRow('Draw Time', drawTimeStr),
                            if (d.forcedWinningNumber != null)
                              _buildInfoRow('Forced Ticket ID', d.forcedWinningNumber!, color: AdminTheme.warning),
                            if (d.winningNumber != null)
                              _buildInfoRow('Drawn Winning Ticket', '#${d.winningNumber!}', color: AdminTheme.success, isBold: true),
                            
                            const Divider(color: AdminTheme.borderColor, height: 24),
                            
                            if (d.status == 'OPEN') ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    style: TextButton.styleFrom(foregroundColor: AdminTheme.error),
                                    onPressed: () => _cancelDraw(d),
                                    child: const Text('CANCEL DRAW'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AdminTheme.primary,
                                      foregroundColor: AdminTheme.background,
                                    ),
                                    onPressed: () => _executeDraw(d),
                                    child: const Text('DRAW WINNER'),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Text(
                                d.status == 'COMPLETED' ? 'Draw Completed successfully.' : 'Draw Cancelled & Refunded.',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AdminTheme.textMuted),
                                textAlign: TextAlign.right,
                              ),
                            ],
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

  Widget _buildInfoRow(String label, String value, {Color? color, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? AdminTheme.textMain,
            ),
          ),
        ],
      ),
    );
  }
}

class LaunchLotteryDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const LaunchLotteryDialog({super.key, required this.onSubmit});

  @override
  State<LaunchLotteryDialog> createState() => _LaunchLotteryDialogState();
}

class _LaunchLotteryDialogState extends State<LaunchLotteryDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController(text: '10');
  final _poolController = TextEditingController(text: '5000');
  final _ticketsController = TextEditingController(text: '1000');
  final _winPercentController = TextEditingController(text: '30');
  final _forcedNumberController = TextEditingController();

  DateTime _drawDate = DateTime.now().add(const Duration(hours: 12));
  TimeOfDay _drawTime = TimeOfDay.now();

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _drawDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _drawTime,
    );
    if (time == null) return;

    setState(() {
      _drawDate = date;
      _drawTime = time;
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final drawTime = DateTime(
        _drawDate.year,
        _drawDate.month,
        _drawDate.day,
        _drawTime.hour,
        _drawTime.minute,
      );

      final forced = _forcedNumberController.text.trim();

      final payload = {
        'title': _titleController.text.trim(),
        'ticket_price': double.parse(_priceController.text),
        'prize_pool': double.parse(_poolController.text),
        'max_tickets': int.parse(_ticketsController.text),
        'win_percentage': double.parse(_winPercentController.text),
        'forced_winning_number': forced.isEmpty ? null : forced,
        'draw_time': drawTime.toUtc().toIso8601String(),
      };

      widget.onSubmit(payload);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drawTimeFormat = '${DateFormat.yMMMd().format(_drawDate)} ${_drawTime.format(context)}';

    return AlertDialog(
      title: const Text('Schedule Lucky Draw'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Lucky Draw Title'),
                validator: (val) => val == null || val.isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Ticket Price (INR)'),
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
                      controller: _ticketsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max Tickets'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _winPercentController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Win Percentage (%)'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _forcedNumberController,
                decoration: const InputDecoration(labelText: 'Force Winner Ticket (Optional)'),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Draw Date & Time', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                subtitle: Text(drawTimeFormat, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textMain)),
                trailing: const Icon(Icons.calendar_today, color: AdminTheme.primary),
                onTap: _pickDateTime,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        TextButton(onPressed: _submit, child: const Text('LAUNCH DRAW', style: TextStyle(color: AdminTheme.primary))),
      ],
    );
  }
}
