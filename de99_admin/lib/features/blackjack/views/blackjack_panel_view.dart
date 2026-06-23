import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';

class BlackjackLogAdmin {
  final int id;
  final int userId;
  final String userPhone;
  final String? userName;
  final double betAmount;
  final double multiplier;
  final double winAmount;
  final String status;
  final DateTime createdAt;
  final double? winProbability;

  BlackjackLogAdmin({
    required this.id,
    required this.userId,
    required this.userPhone,
    this.userName,
    required this.betAmount,
    required this.multiplier,
    required this.winAmount,
    required this.status,
    required this.createdAt,
    this.winProbability,
  });

  factory BlackjackLogAdmin.fromJson(Map<String, dynamic> json) {
    return BlackjackLogAdmin(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      userPhone: json['user_phone'] as String,
      userName: json['user_name'] as String?,
      betAmount: (json['bet_amount'] as num).toDouble(),
      multiplier: (json['multiplier'] as num).toDouble(),
      winAmount: (json['win_amount'] as num).toDouble(),
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      winProbability: json['win_probability'] != null ? (json['win_probability'] as num).toDouble() : null,
    );
  }
}

class BlackjackStatsAdmin {
  final int totalGames;
  final double totalBetAmount;
  final double totalWinningsPaid;
  final double platformNetProfit;
  final double payoutRatio;

  BlackjackStatsAdmin({
    required this.totalGames,
    required this.totalBetAmount,
    required this.totalWinningsPaid,
    required this.platformNetProfit,
    required this.payoutRatio,
  });

  factory BlackjackStatsAdmin.fromJson(Map<String, dynamic> json) {
    return BlackjackStatsAdmin(
      totalGames: json['total_games'] as int,
      totalBetAmount: (json['total_bet_amount'] as num).toDouble(),
      totalWinningsPaid: (json['total_winnings_paid'] as num).toDouble(),
      platformNetProfit: (json['platform_net_profit'] as num).toDouble(),
      payoutRatio: (json['payout_ratio'] as num).toDouble(),
    );
  }
}

class BlackjackSettingsAdmin {
  final double winningPercentage;
  final double minBet;
  final double maxBet;
  final bool maintenanceMode;

  BlackjackSettingsAdmin({
    required this.winningPercentage,
    required this.minBet,
    required this.maxBet,
    required this.maintenanceMode,
  });

  factory BlackjackSettingsAdmin.fromJson(Map<String, dynamic> json) {
    return BlackjackSettingsAdmin(
      winningPercentage: (json['winning_percentage'] as num).toDouble(),
      minBet: (json['min_bet'] as num).toDouble(),
      maxBet: (json['max_bet'] as num).toDouble(),
      maintenanceMode: json['maintenance_mode'] as bool,
    );
  }
}

class BlackjackPanelView extends StatefulWidget {
  const BlackjackPanelView({super.key});

  @override
  State<BlackjackPanelView> createState() => _BlackjackPanelViewState();
}

class _BlackjackPanelViewState extends State<BlackjackPanelView> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  
  bool _isLoading = false;
  String? _error;
  
  BlackjackStatsAdmin? _stats;
  BlackjackSettingsAdmin? _settings;
  List<BlackjackLogAdmin> _logs = [];

  final _winRateController = TextEditingController();
  final _minBetController = TextEditingController();
  final _maxBetController = TextEditingController();

  bool _maintenanceVal = false;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _winRateController.dispose();
    _minBetController.dispose();
    _maxBetController.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statsResponse = await _apiClient.dio.get('/admin/blackjack/stats');
      final settingsResponse = await _apiClient.dio.get('/admin/blackjack/settings');
      final logsResponse = await _apiClient.dio.get('/admin/blackjack/logs');

      final stats = BlackjackStatsAdmin.fromJson(statsResponse.data);
      final settings = BlackjackSettingsAdmin.fromJson(settingsResponse.data);
      final logs = (logsResponse.data as List)
          .map((json) => BlackjackLogAdmin.fromJson(json))
          .toList();

      setState(() {
        _stats = stats;
        _settings = settings;
        _logs = logs;
        _isLoading = false;

        _winRateController.text = settings.winningPercentage.toStringAsFixed(0);
        _minBetController.text = settings.minBet.toString();
        _maxBetController.text = settings.maxBet.toString();
        _maintenanceVal = settings.maintenanceMode;
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.response?.data['detail'] ?? e.message ?? 'Network error';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _updateSettings() async {
    final winPercentage = double.tryParse(_winRateController.text) ?? 50.0;
    final minBet = double.tryParse(_minBetController.text) ?? 10.0;
    final maxBet = double.tryParse(_maxBetController.text) ?? 50000.0;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.dio.post(
        '/admin/blackjack/settings',
        data: {
          'winning_percentage': winPercentage,
          'min_bet': minBet,
          'max_bet': maxBet,
          'maintenance_mode': _maintenanceVal,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Blackjack settings updated!'), backgroundColor: AdminTheme.success),
      );
      setState(() {
        _settings = BlackjackSettingsAdmin.fromJson(response.data);
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

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    if (_isLoading && _stats == null) {
      return const Center(child: CircularProgressIndicator(color: AdminTheme.primary));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: AdminTheme.error),
            const SizedBox(height: 12),
            Text(_error!),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _refreshAll, child: const Text('Retry')),
          ],
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
              'Blackjack operational Controls',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AdminTheme.primary),
            ),
            const SizedBox(height: 16),
            if (_stats != null) ...[
              _buildStatsGrid(_stats!, currencyFormatter),
              const SizedBox(height: 20),
            ],
            _buildConfigurationPanel(),
            const SizedBox(height: 20),
            const Text(
              'Recent Blackjack Sessions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
            ),
            const SizedBox(height: 12),
            _buildLogsList(currencyFormatter),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BlackjackStatsAdmin stats, NumberFormat formatter) {
    final bool isWide = MediaQuery.of(context).size.width > 800;
    if (isWide) {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard('Total Played', stats.totalGames.toString(), Icons.gamepad_outlined, AdminTheme.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard('Total Bets', formatter.format(stats.totalBetAmount), Icons.payments_outlined, AdminTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard('Winnings Paid', formatter.format(stats.totalWinningsPaid), Icons.emoji_events_outlined, AdminTheme.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard('Net Profit', formatter.format(stats.platformNetProfit), Icons.account_balance_wallet_outlined, stats.platformNetProfit >= 0 ? AdminTheme.success : AdminTheme.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard('Payout RTP', '${stats.payoutRatio.toStringAsFixed(1)}%', Icons.percent_outlined, AdminTheme.secondary),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total Played', stats.totalGames.toString(), Icons.gamepad_outlined, AdminTheme.info),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Total Bets', formatter.format(stats.totalBetAmount), Icons.payments_outlined, AdminTheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Winnings Paid', formatter.format(stats.totalWinningsPaid), Icons.emoji_events_outlined, AdminTheme.warning),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Net Profit', formatter.format(stats.platformNetProfit), Icons.account_balance_wallet_outlined, stats.platformNetProfit >= 0 ? AdminTheme.success : AdminTheme.error),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Payout RTP', '${stats.payoutRatio.toStringAsFixed(1)}%', Icons.percent_outlined, AdminTheme.secondary),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigurationPanel() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, color: AdminTheme.primary, size: 20),
                SizedBox(width: 8),
                Text('Operational settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AdminTheme.textMain)),
              ],
            ),
            const Divider(color: AdminTheme.borderColor, height: 24),
            TextFormField(
              controller: _minBetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Minimum Bet (INR)', prefixIcon: Icon(Icons.currency_rupee)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxBetController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Maximum Bet (INR)', prefixIcon: Icon(Icons.currency_rupee)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _winRateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Player Target Win Rate % (0 - 100)', prefixIcon: Icon(Icons.percent)),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AdminTheme.error,
              title: const Text('Maintenance Mode', style: TextStyle(fontSize: 14, color: AdminTheme.textMain)),
              subtitle: const Text('Instantly lock Blackjack access for players', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted)),
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
              child: const Text('SAVE BLACKJACK CONFIG', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList(NumberFormat formatter) {
    if (_logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('No game logs found.', style: TextStyle(color: AdminTheme.textMuted))),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index];
        final isWin = log.status.contains('WON') || log.status.contains('BLACKJACK');
        final isLoss = log.status.contains('LOST') || log.status.contains('BUST');
        
        Color statusColor = AdminTheme.warning;
        if (isWin) statusColor = AdminTheme.success;
        if (isLoss) statusColor = AdminTheme.error;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: statusColor.withOpacity(0.1),
                  child: Icon(isWin ? Icons.trending_up : (isLoss ? Icons.trending_down : Icons.help_outline), color: statusColor),
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
                        'Bet: ${formatter.format(log.betAmount)} | Win Prob: ${log.winProbability != null ? '${log.winProbability!.toStringAsFixed(0)}%' : '-'} | Status: ${log.status}',
                        style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11),
                      ),
                      Text(
                        DateFormat.yMMMd().add_jm().format(log.createdAt),
                        style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isWin ? '+${formatter.format(log.winAmount)}' : (isLoss ? '-${formatter.format(log.betAmount)}' : 'PLAYING'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isWin ? AdminTheme.success : (isLoss ? AdminTheme.error : AdminTheme.warning),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('${log.multiplier.toStringAsFixed(2)}x', style: const TextStyle(color: AdminTheme.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
