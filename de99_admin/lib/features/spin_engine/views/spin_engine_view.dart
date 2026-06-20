import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';

class SpinStats {
  final int totalSpins;
  final double totalWinnings;
  final double totalBets;
  final double netProfit;
  final double payoutRatio;

  SpinStats({
    required this.totalSpins,
    required this.totalWinnings,
    required this.totalBets,
    required this.netProfit,
    required this.payoutRatio,
  });

  factory SpinStats.fromJson(Map<String, dynamic> json) {
    return SpinStats(
      totalSpins: json['total_spins'] ?? 0,
      totalWinnings: (json['total_winnings_paid'] ?? 0).toDouble(),
      totalBets: (json['total_bet_amount'] ?? 0).toDouble(),
      netProfit: (json['platform_net_profit'] ?? 0).toDouble(),
      payoutRatio: (json['payout_ratio'] ?? 0).toDouble(),
    );
  }
}

class SpinRtpSetting {
  final int id;
  final double minAmount;
  final double maxAmount;
  final String probabilityJson;
  final bool enabled;

  SpinRtpSetting({
    required this.id,
    required this.minAmount,
    required this.maxAmount,
    required this.probabilityJson,
    required this.enabled,
  });

  factory SpinRtpSetting.fromJson(Map<String, dynamic> json) {
    return SpinRtpSetting(
      id: json['id'] ?? 0,
      minAmount: (json['min_amount'] ?? 0).toDouble(),
      maxAmount: (json['max_amount'] ?? 0).toDouble(),
      probabilityJson: json['probability_json'] ?? '{}',
      enabled: json['enabled'] ?? true,
    );
  }
}

class SuspiciousUser {
  final int userId;
  final String name;
  final String phone;
  final int totalSpins;
  final double winRatio;
  final double netProfit;

  SuspiciousUser({
    required this.userId,
    required this.name,
    required this.phone,
    required this.totalSpins,
    required this.winRatio,
    required this.netProfit,
  });

  factory SuspiciousUser.fromJson(Map<String, dynamic> json) {
    return SuspiciousUser(
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? 'Anonymous',
      phone: json['phone'] ?? '',
      totalSpins: json['total_spins'] ?? 0,
      winRatio: (json['win_ratio'] ?? 0).toDouble(),
      netProfit: ((json['total_win'] ?? 0) - (json['total_bet'] ?? 0)).toDouble(),
    );
  }
}

class SpinLogItem {
  final int id;
  final int userId;
  final String userName;
  final String userPhone;
  final double betAmount;
  final double multiplier;
  final double winAmount;
  final String resultType;
  final String wheelSegment;
  final DateTime createdAt;

  SpinLogItem({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    required this.betAmount,
    required this.multiplier,
    required this.winAmount,
    required this.resultType,
    required this.wheelSegment,
    required this.createdAt,
  });

  factory SpinLogItem.fromJson(Map<String, dynamic> json) {
    return SpinLogItem(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      userName: json['user_name'] ?? json['user_phone'] ?? 'User',
      userPhone: json['user_phone'] ?? '',
      betAmount: (json['bet_amount'] ?? 0).toDouble(),
      multiplier: (json['multiplier'] ?? 0).toDouble(),
      winAmount: (json['win_amount'] ?? 0).toDouble(),
      resultType: json['result_type'] ?? 'LOSE',
      wheelSegment: json['wheel_segment'] ?? 'Lose',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }
}

class SpinEngineView extends StatefulWidget {
  const SpinEngineView({super.key});

  @override
  State<SpinEngineView> createState() => _SpinEngineViewState();
}

class _SpinEngineViewState extends State<SpinEngineView> with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  late TabController _tabController;

  bool _isLoading = false;
  String? _error;

  SpinStats? _stats;
  bool _maintenanceVal = false;
  List<SpinRtpSetting> _rtps = [];
  List<SuspiciousUser> _suspicious = [];
  List<SpinLogItem> _logs = [];

  // Edit RTP state
  SpinRtpSetting? _selectedRtp;
  final _rtpJsonEditorController = TextEditingController();

  // Create RTP state
  final _createMinBetController = TextEditingController();
  final _createMaxBetController = TextEditingController();
  final _createJsonController = TextEditingController(
    text: '{\n  "Lose": 50,\n  "1x": 20,\n  "1.5x": 15,\n  "2x": 10,\n  "5x": 4,\n  "10x": 1\n}',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _rtpJsonEditorController.dispose();
    _createMinBetController.dispose();
    _createMaxBetController.dispose();
    _createJsonController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statsRes = await _apiClient.dio.get('/admin/spin/stats');
      final maintenanceRes = await _apiClient.dio.get('/admin/maintenance');
      final rtpRes = await _apiClient.dio.get('/admin/rtp');
      final suspiciousRes = await _apiClient.dio.get('/admin/suspicious-users');
      final logsRes = await _apiClient.dio.get('/admin/spin/logs');

      setState(() {
        _stats = SpinStats.fromJson(statsRes.data);
        _maintenanceVal = maintenanceRes.data['maintenance_mode'] as bool? ?? false;
        
        _rtps = (rtpRes.data as List).map((x) => SpinRtpSetting.fromJson(x)).toList();
        _suspicious = (suspiciousRes.data as List).map((x) => SuspiciousUser.fromJson(x)).toList();
        _logs = (logsRes.data as List).map((x) => SpinLogItem.fromJson(x)).toList();
        
        _isLoading = false;

        if (_rtps.isNotEmpty) {
          _selectRtp(_rtps.first);
        } else {
          _selectedRtp = null;
          _rtpJsonEditorController.clear();
        }
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.response?.data['detail'] ?? e.message ?? 'Network error in Casino Spin controller';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _selectRtp(SpinRtpSetting rtp) {
    setState(() {
      _selectedRtp = rtp;
      try {
        final Map<String, dynamic> parsed = jsonDecode(rtp.probabilityJson);
        final encoder = JsonEncoder.withIndent('  ');
        _rtpJsonEditorController.text = encoder.convert(parsed);
      } catch (_) {
        _rtpJsonEditorController.text = rtp.probabilityJson;
      }
    });
  }

  Future<void> _toggleMaintenance(bool val) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await _apiClient.dio.post('/admin/maintenance', queryParameters: {'enabled': val});
      setState(() {
        _maintenanceVal = res.data['maintenance_mode'] as bool? ?? val;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_maintenanceVal ? 'Spin Wheel is now locked for players!' : 'Spin Wheel is live!'),
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

  Future<void> _saveRtpOverride() async {
    if (_selectedRtp == null) return;
    final rawJson = _rtpJsonEditorController.text.trim();

    try {
      final Map<String, dynamic> parsed = jsonDecode(rawJson);
      final double sum = parsed.values.fold(0.0, (prev, element) => prev + (element as num).toDouble());
      if ((sum - 100.0).abs() > 1.0) {
        throw Exception('Outcome weights must sum to exactly 100%. (Current sum is ${sum.toStringAsFixed(1)}%)');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid JSON formatting: ${e.toString()}'), backgroundColor: AdminTheme.error),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.put(
        '/admin/rtp/${_selectedRtp!.id}',
        data: {
          'probability_json': jsonEncode(jsonDecode(rawJson)),
          'enabled': true,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RTP settings update applied!'), backgroundColor: AdminTheme.success),
      );
      await _refreshAll();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to save RTP override'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRtpOverride() async {
    if (_selectedRtp == null) return;
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to delete this specific bet range RTP override?'),
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
      await _apiClient.dio.delete('/admin/rtp/${_selectedRtp!.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RTP Override deleted successfully.'), backgroundColor: AdminTheme.success),
      );
      await _refreshAll();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to delete override'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createRtpOverride() async {
    final minBet = double.tryParse(_createMinBetController.text);
    final maxBet = double.tryParse(_createMaxBetController.text);
    final rawJson = _createJsonController.text.trim();

    if (minBet == null || maxBet == null || rawJson.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid bets limits and probability weights.'), backgroundColor: AdminTheme.error),
      );
      return;
    }

    try {
      final Map<String, dynamic> parsed = jsonDecode(rawJson);
      final double sum = parsed.values.fold(0.0, (prev, element) => prev + (element as num).toDouble());
      if ((sum - 100.0).abs() > 1.0) {
        throw Exception('Weights must sum to exactly 100%. (Current sum: ${sum.toStringAsFixed(1)}%)');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid JSON formatting: ${e.toString()}'), backgroundColor: AdminTheme.error),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.post(
        '/admin/rtp',
        data: {
          'min_amount': minBet,
          'max_amount': maxBet,
          'probability_json': jsonEncode(jsonDecode(rawJson)),
          'enabled': true,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RTP safety override tier created!'), backgroundColor: AdminTheme.success),
      );
      _createMinBetController.clear();
      _createMaxBetController.clear();
      await _refreshAll();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to create override'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildConfigTab(NumberFormat currencyFormatter) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Edit RTP card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('RTP Probability Configurator', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (_rtps.isEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No custom RTP ranges configured.', style: TextStyle(color: AdminTheme.textMuted, fontStyle: FontStyle.italic)),
                    ),
                  ] else ...[
                    DropdownButtonFormField<SpinRtpSetting>(
                      value: _selectedRtp,
                      decoration: const InputDecoration(labelText: 'RTP Bet Range override'),
                      items: _rtps.map((r) {
                        final label = r.minAmount == r.maxAmount
                            ? 'Exact Bet ₹${r.minAmount.toStringAsFixed(0)}'
                            : 'Bets ₹${r.minAmount.toStringAsFixed(0)} – ₹${r.maxAmount.toStringAsFixed(0)}';
                        return DropdownMenuItem<SpinRtpSetting>(value: r, child: Text(label));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) _selectRtp(val);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rtpJsonEditorController,
                      maxLines: 7,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.green),
                      decoration: const InputDecoration(
                        labelText: 'Probability Weights (JSON format)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.primary,
                              foregroundColor: AdminTheme.background,
                            ),
                            onPressed: _saveRtpOverride,
                            child: const Text('SAVE RTP SETTINGS'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminTheme.error,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _deleteRtpOverride,
                            child: const Text('DELETE SELECTED'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Create Override card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Create Bet Override / RTP Tier', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.primary)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _createMinBetController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Min Bet (INR)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _createMaxBetController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Max Bet (INR)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _createJsonController,
                    maxLines: 5,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.green),
                    decoration: const InputDecoration(
                      labelText: 'Weights mapping JSON',
                      border: OutlineInputBorder(),
                      helperText: 'Mapping target segment multiplier to percentage weight. Sum must be 100%.',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.secondary,
                      foregroundColor: AdminTheme.textMain,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _createRtpOverride,
                    child: const Text('CREATE OVERRIDE / TIER', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTab(NumberFormat currencyFormatter) {
    if (_suspicious.isEmpty) {
      return const Center(child: Text('No suspicious activity flagged.', style: TextStyle(color: AdminTheme.textMuted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _suspicious.length,
      itemBuilder: (context, index) {
        final u = _suspicious[index];
        final isProfit = u.netProfit >= 0;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${u.phone} (ID: ${u.userId})', style: const TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                Text('Total Spins: ${u.totalSpins} | Win Ratio: ${u.winRatio.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12)),
              ],
            ),
            trailing: Text(
              '${isProfit ? "+" : ""}${currencyFormatter.format(u.netProfit)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isProfit ? AdminTheme.success : AdminTheme.error,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogsTab(NumberFormat currencyFormatter) {
    if (_logs.isEmpty) {
      return const Center(child: Text('No spins transactions logged yet.', style: TextStyle(color: AdminTheme.textMuted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final l = _logs[index];
        final isWin = l.winAmount > 0;
        final timeStr = DateFormat.yMMMd().add_jm().format(l.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: (isWin ? AdminTheme.success : AdminTheme.error).withOpacity(0.1),
                  child: Icon(
                    isWin ? Icons.trending_up : Icons.trending_down,
                    color: isWin ? AdminTheme.success : AdminTheme.error,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${l.userName} (${l.userPhone})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('Bet: ${currencyFormatter.format(l.betAmount)} | Segment: ${l.wheelSegment}', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                      Text(timeStr, style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isWin ? "+" : "-"}${currencyFormatter.format(isWin ? l.winAmount : l.betAmount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isWin ? AdminTheme.success : AdminTheme.error,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${l.multiplier.toStringAsFixed(1)}x', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    if (_isLoading && _stats == null) {
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
              ElevatedButton(onPressed: _refreshAll, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

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
              Tab(icon: Icon(Icons.settings), text: 'RTP Config'),
              Tab(icon: Icon(Icons.warning_amber), text: 'Audit Watch'),
              Tab(icon: Icon(Icons.history), text: 'Spin Logs'),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: Column(
          children: [
            // KPI metrics header & maintenance lockout bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_stats != null) ...[
                    Row(
                      children: [
                        Expanded(child: _buildMetricCard('Bets Volume', currencyFormatter.format(_stats!.totalBets), Icons.payments, AdminTheme.primary)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMetricCard('House Margin', currencyFormatter.format(_stats!.netProfit), Icons.account_balance_wallet, _stats!.netProfit >= 0 ? AdminTheme.success : AdminTheme.error)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildMetricCard('Payout RTP', '${_stats!.payoutRatio.toStringAsFixed(1)}%', Icons.percent, AdminTheme.warning)),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: AdminTheme.error,
                    title: const Text('Spin Wheel Maintenance Lock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Lock Casino spin wheel access for all players instantly', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                    value: _maintenanceVal,
                    onChanged: _toggleMaintenance,
                  ),
                ],
              ),
            ),
            const Divider(color: AdminTheme.borderColor, height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildConfigTab(currencyFormatter),
                  _buildAuditTab(currencyFormatter),
                  _buildLogsTab(currencyFormatter),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 10, color: AdminTheme.textMuted)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AdminTheme.textMain), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
