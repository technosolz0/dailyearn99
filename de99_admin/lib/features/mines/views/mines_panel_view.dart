import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';

class MinesLogAdmin {
  final int id;
  final int userId;
  final String userPhone;
  final String? userName;
  final double betAmount;
  final int minesCount;
  final double multiplier;
  final double winAmount;
  final String resultType;
  final DateTime createdAt;
  final double? winProbability;

  MinesLogAdmin({
    required this.id,
    required this.userId,
    required this.userPhone,
    this.userName,
    required this.betAmount,
    required this.minesCount,
    required this.multiplier,
    required this.winAmount,
    required this.resultType,
    required this.createdAt,
    this.winProbability,
  });

  factory MinesLogAdmin.fromJson(Map<String, dynamic> json) {
    return MinesLogAdmin(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      userPhone: json['user_phone'] as String,
      userName: json['user_name'] as String?,
      betAmount: (json['bet_amount'] as num).toDouble(),
      minesCount: json['mines_count'] as int,
      multiplier: (json['multiplier'] as num).toDouble(),
      winAmount: (json['win_amount'] as num).toDouble(),
      resultType: json['result_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      winProbability: json['win_probability'] != null ? (json['win_probability'] as num).toDouble() : null,
    );
  }
}

class MinesStatsAdmin {
  final int totalGames;
  final double totalBetAmount;
  final double totalWinningsPaid;
  final double platformNetProfit;
  final double payoutRatio;

  MinesStatsAdmin({
    required this.totalGames,
    required this.totalBetAmount,
    required this.totalWinningsPaid,
    required this.platformNetProfit,
    required this.payoutRatio,
  });

  factory MinesStatsAdmin.fromJson(Map<String, dynamic> json) {
    return MinesStatsAdmin(
      totalGames: json['total_games'] as int,
      totalBetAmount: (json['total_bet_amount'] as num).toDouble(),
      totalWinningsPaid: (json['total_winnings_paid'] as num).toDouble(),
      platformNetProfit: (json['platform_net_profit'] as num).toDouble(),
      payoutRatio: (json['payout_ratio'] as num).toDouble(),
    );
  }
}

class MinesSettingsAdmin {
  final double houseEdge;
  final double minBet;
  final double maxBet;
  final bool maintenanceMode;

  MinesSettingsAdmin({
    required this.houseEdge,
    required this.minBet,
    required this.maxBet,
    required this.maintenanceMode,
  });

  factory MinesSettingsAdmin.fromJson(Map<String, dynamic> json) {
    return MinesSettingsAdmin(
      houseEdge: (json['house_edge'] as num).toDouble(),
      minBet: (json['min_bet'] as num).toDouble(),
      maxBet: (json['max_bet'] as num).toDouble(),
      maintenanceMode: json['maintenance_mode'] as bool,
    );
  }
}

class MinesRtpRule {
  final int id;
  final double minAmount;
  final double maxAmount;
  final double winRate;
  final bool enabled;

  MinesRtpRule({
    required this.id,
    required this.minAmount,
    required this.maxAmount,
    required this.winRate,
    required this.enabled,
  });

  factory MinesRtpRule.fromJson(Map<String, dynamic> json) {
    return MinesRtpRule(
      id: json['id'] as int,
      minAmount: (json['min_amount'] as num).toDouble(),
      maxAmount: (json['max_amount'] as num).toDouble(),
      winRate: (json['win_rate'] as num).toDouble(),
      enabled: json['enabled'] as bool,
    );
  }
}

class MinesPanelView extends StatefulWidget {
  const MinesPanelView({super.key});

  @override
  State<MinesPanelView> createState() => _MinesPanelViewState();
}

class _MinesPanelViewState extends State<MinesPanelView> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  
  bool _isLoading = false;
  String? _error;
  
  MinesStatsAdmin? _stats;
  MinesSettingsAdmin? _settings;
  List<MinesLogAdmin> _logs = [];
  List<MinesRtpRule> _rtpRules = [];

  final _houseEdgeController = TextEditingController();
  final _minBetController = TextEditingController();
  final _maxBetController = TextEditingController();

  final _rtpMinBetController = TextEditingController();
  final _rtpMaxBetController = TextEditingController();
  final _rtpWinRateController = TextEditingController();

  bool _maintenanceVal = false;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _houseEdgeController.dispose();
    _minBetController.dispose();
    _maxBetController.dispose();
    _rtpMinBetController.dispose();
    _rtpMaxBetController.dispose();
    _rtpWinRateController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statsResponse = await _apiClient.dio.get('/admin/mines/stats');
      final settingsResponse = await _apiClient.dio.get('/admin/mines/settings');
      final logsResponse = await _apiClient.dio.get('/admin/mines/logs');
      final rtpResponse = await _apiClient.dio.get('/admin/mines/rtp');

      final stats = MinesStatsAdmin.fromJson(statsResponse.data);
      final settings = MinesSettingsAdmin.fromJson(settingsResponse.data);
      final logs = (logsResponse.data as List)
          .map((json) => MinesLogAdmin.fromJson(json))
          .toList();
      final rtpRules = (rtpResponse.data as List)
          .map((json) => MinesRtpRule.fromJson(json))
          .toList();

      setState(() {
        _stats = stats;
        _settings = settings;
        _logs = logs;
        _rtpRules = rtpRules;
        _isLoading = false;

        // Initialize controllers
        _houseEdgeController.text = settings.houseEdge.toString();
        _minBetController.text = settings.minBet.toString();
        _maxBetController.text = settings.maxBet.toString();
        _maintenanceVal = settings.maintenanceMode;
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.response?.data['detail'] ?? e.message ?? 'Unknown network failure';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _updateSettings() async {
    final edge = double.tryParse(_houseEdgeController.text) ?? 0.03;
    final minBet = double.tryParse(_minBetController.text) ?? 10.0;
    final maxBet = double.tryParse(_maxBetController.text) ?? 5000.0;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.dio.post(
        '/admin/mines/settings',
        data: {
          'house_edge': edge,
          'min_bet': minBet,
          'max_bet': maxBet,
          'maintenance_mode': _maintenanceVal,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mines configuration updated successfully!'), backgroundColor: AdminTheme.success),
      );
      setState(() {
        _settings = MinesSettingsAdmin.fromJson(response.data);
        _isLoading = false;
      });
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to update settings'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _createRtpRule() async {
    final min = double.tryParse(_rtpMinBetController.text);
    final max = double.tryParse(_rtpMaxBetController.text);
    final rate = double.tryParse(_rtpWinRateController.text);

    if (min == null || max == null || rate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid values.'), backgroundColor: AdminTheme.error),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.post(
        '/admin/mines/rtp',
        data: {
          'min_amount': min,
          'max_amount': max,
          'win_rate': rate,
          'enabled': true,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RTP override rule added successfully!'), backgroundColor: AdminTheme.success),
      );
      _rtpMinBetController.clear();
      _rtpMaxBetController.clear();
      _rtpWinRateController.clear();
      await _refreshAll();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to add rule'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRtpRule(int id) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.delete('/admin/mines/rtp/$id');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RTP override rule deleted!'), backgroundColor: AdminTheme.success),
      );
      await _refreshAll();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to delete rule'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
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
              ElevatedButton(
                onPressed: _refreshAll,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Mines Game Admin settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.primary),
            ),
            const SizedBox(height: 16),
            
            // Stats Grid
            if (_stats != null) ...[
              _buildStatsCardGrid(_stats!, currencyFormatter),
              const SizedBox(height: 20),
            ],

            // Configuration Form
            _buildConfigurationPanel(),
            const SizedBox(height: 20),

            // RTP overrides
            _buildRtpOverridesPanel(),
            const SizedBox(height: 24),

            // Game Logs
            const Text(
              'Recent Game Logs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
            ),
            const SizedBox(height: 12),
            _buildLogsList(currencyFormatter),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCardGrid(MinesStatsAdmin stats, NumberFormat currencyFormatter) {
    final bool isWide = MediaQuery.of(context).size.width > 800;
    if (isWide) {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Total Games Played',
              value: stats.totalGames.toString(),
              icon: Icons.gamepad_outlined,
              color: AdminTheme.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Total Bet Turnover',
              value: currencyFormatter.format(stats.totalBetAmount),
              icon: Icons.payments_outlined,
              color: AdminTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Winnings Distributed',
              value: currencyFormatter.format(stats.totalWinningsPaid),
              icon: Icons.emoji_events_outlined,
              color: AdminTheme.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Platform Profit',
              value: currencyFormatter.format(stats.platformNetProfit),
              icon: Icons.account_balance_wallet_outlined,
              color: stats.platformNetProfit >= 0 ? AdminTheme.success : AdminTheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Payout RTP Ratio',
              value: '${stats.payoutRatio.toStringAsFixed(1)}%',
              icon: Icons.percent_outlined,
              color: AdminTheme.secondary,
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Total Games Played',
                  value: stats.totalGames.toString(),
                  icon: Icons.gamepad_outlined,
                  color: AdminTheme.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Total Bet Turnover',
                  value: currencyFormatter.format(stats.totalBetAmount),
                  icon: Icons.payments_outlined,
                  color: AdminTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Winnings Distributed',
                  value: currencyFormatter.format(stats.totalWinningsPaid),
                  icon: Icons.emoji_events_outlined,
                  color: AdminTheme.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Platform Profit',
                  value: currencyFormatter.format(stats.platformNetProfit),
                  icon: Icons.account_balance_wallet_outlined,
                  color: stats.platformNetProfit >= 0 ? AdminTheme.success : AdminTheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'Payout RTP Ratio',
                  value: '${stats.payoutRatio.toStringAsFixed(1)}%',
                  icon: Icons.percent_outlined,
                  color: AdminTheme.secondary,
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AdminTheme.textMain)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationPanel() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune, color: AdminTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Operational settings',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminTheme.textMain),
                  ),
                ],
              ),
              const Divider(color: AdminTheme.borderColor, height: 24),
              TextFormField(
                controller: _minBetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Bet (INR)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxBetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum Bet (INR)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _houseEdgeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'House Edge Factor (e.g. 0.03 for 3%)',
                  prefixIcon: Icon(Icons.show_chart),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AdminTheme.error,
                title: const Text('Maintenance Mode', style: TextStyle(fontSize: 14, color: AdminTheme.textMain)),
                subtitle: const Text('Disable all Mines bets for players', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
                value: _maintenanceVal,
                onChanged: (val) {
                  setState(() {
                    _maintenanceVal = val;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.primary,
                  foregroundColor: AdminTheme.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _updateSettings,
                child: const Text('SAVE CONFIGURATION', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRtpOverridesPanel() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.percent_outlined, color: AdminTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Win Rate Overrides (RTP settings)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminTheme.textMain),
                ),
              ],
            ),
            const Divider(color: AdminTheme.borderColor, height: 24),
            
            if (_rtpRules.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('No active range override rules configured.', style: TextStyle(color: AdminTheme.textMuted, fontSize: 13)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rtpRules.length,
                itemBuilder: (context, index) {
                  final rule = _rtpRules[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Bets ₹${rule.minAmount.toStringAsFixed(0)} – ₹${rule.maxAmount.toStringAsFixed(0)}'),
                    subtitle: Text('Force Win Rate: ${(rule.winRate * 100).toStringAsFixed(0)}% safety probability'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: AdminTheme.error),
                      onPressed: () => _deleteRtpRule(rule.id),
                    ),
                  );
                },
              ),
            
            const Divider(color: AdminTheme.borderColor, height: 24),
            const Text(
              'Create Custom Override Rule',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.primary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rtpMinBetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min Bet'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _rtpMaxBetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max Bet'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _rtpWinRateController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Win Rate (0-1)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.secondary,
                foregroundColor: AdminTheme.textMain,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _createRtpRule,
              child: const Text('ADD WIN OVERRIDE RULE', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList(NumberFormat currencyFormatter) {
    if (_logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Center(
            child: Text('No game transactions logged yet.', style: TextStyle(color: AdminTheme.textMuted)),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final isWin = log.resultType == 'WON';
        final isLoss = log.resultType == 'LOST';
        
        Color statusColor = AdminTheme.warning;
        if (isWin) statusColor = AdminTheme.success;
        if (isLoss) statusColor = AdminTheme.error;

        final timeStr = DateFormat.yMMMd().add_jm().format(log.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(
                    isWin ? Icons.trending_up : (isLoss ? Icons.trending_down : Icons.help_outline),
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.userName != null ? '${log.userName} (${log.userPhone})' : log.userPhone,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AdminTheme.textMain),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bet: ${currencyFormatter.format(log.betAmount)} | ${log.minesCount} Mines | Win Prob: ${log.winProbability != null ? '${(log.winProbability! * 100).toStringAsFixed(0)}%' : '-'}',
                        style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isWin ? '+${currencyFormatter.format(log.winAmount)}' : (isLoss ? '-${currencyFormatter.format(log.betAmount)}' : 'PLAYING'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isWin ? AdminTheme.success : (isLoss ? AdminTheme.error : AdminTheme.warning),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${log.multiplier.toStringAsFixed(2)}x',
                      style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
