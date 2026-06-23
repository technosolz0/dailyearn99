import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';

class PlinkoLogAdmin {
  final int id;
  final int userId;
  final String userPhone;
  final String? userName;
  final double betAmount;
  final int rows;
  final String mode;
  final double multiplier;
  final double winAmount;
  final DateTime createdAt;
  final double? winProbability;

  PlinkoLogAdmin({
    required this.id,
    required this.userId,
    required this.userPhone,
    this.userName,
    required this.betAmount,
    required this.rows,
    required this.mode,
    required this.multiplier,
    required this.winAmount,
    required this.createdAt,
    this.winProbability,
  });

  factory PlinkoLogAdmin.fromJson(Map<String, dynamic> json) {
    return PlinkoLogAdmin(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      userPhone: json['user_phone'] as String,
      userName: json['user_name'] as String?,
      betAmount: (json['bet_amount'] as num).toDouble(),
      rows: json['rows'] as int,
      mode: json['mode'] as String,
      multiplier: (json['multiplier'] as num).toDouble(),
      winAmount: (json['win_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      winProbability: json['win_probability'] != null
          ? (json['win_probability'] as num).toDouble()
          : null,
    );
  }
}

class PlinkoStatsAdmin {
  final int totalGames;
  final double totalBetAmount;
  final double totalWinningsPaid;
  final double platformNetProfit;
  final double payoutRatio;

  PlinkoStatsAdmin({
    required this.totalGames,
    required this.totalBetAmount,
    required this.totalWinningsPaid,
    required this.platformNetProfit,
    required this.payoutRatio,
  });

  factory PlinkoStatsAdmin.fromJson(Map<String, dynamic> json) {
    return PlinkoStatsAdmin(
      totalGames: json['total_games'] as int,
      totalBetAmount: (json['total_bet_amount'] as num).toDouble(),
      totalWinningsPaid: (json['total_winnings_paid'] as num).toDouble(),
      platformNetProfit: (json['platform_net_profit'] as num).toDouble(),
      payoutRatio: (json['payout_ratio'] as num).toDouble(),
    );
  }
}

class PlinkoSettingsAdmin {
  final double minBet;
  final double maxBet;
  final bool maintenanceMode;

  PlinkoSettingsAdmin({
    required this.minBet,
    required this.maxBet,
    required this.maintenanceMode,
  });

  factory PlinkoSettingsAdmin.fromJson(Map<String, dynamic> json) {
    return PlinkoSettingsAdmin(
      minBet: (json['min_bet'] as num).toDouble(),
      maxBet: (json['max_bet'] as num).toDouble(),
      maintenanceMode: json['maintenance_mode'] as bool,
    );
  }
}

class PlinkoMultiplierOverride {
  final int id;
  final int rows;
  final String mode;
  final List<double> multipliers;

  PlinkoMultiplierOverride({
    required this.id,
    required this.rows,
    required this.mode,
    required this.multipliers,
  });
}

class PlinkoRtpOverride {
  final int id;
  final double minAmount;
  final double maxAmount;
  final int rows;
  final String mode;
  final Map<String, double> probabilities;
  final bool enabled;

  PlinkoRtpOverride({
    required this.id,
    required this.minAmount,
    required this.maxAmount,
    required this.rows,
    required this.mode,
    required this.probabilities,
    required this.enabled,
  });

  factory PlinkoRtpOverride.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> rawProb = json['probability_json'] is String
        ? Map<String, dynamic>.from(
            (json['probability_json'] as String).isEmpty
                ? {}
                : (jsonDecode(json['probability_json'])),
          )
        : Map<String, dynamic>.from(json['probability_json'] ?? {});
    final Map<String, double> probs = {};
    rawProb.forEach((key, val) {
      probs[key] = (val as num).toDouble();
    });

    return PlinkoRtpOverride(
      id: json['id'] as int,
      minAmount: (json['min_amount'] as num).toDouble(),
      maxAmount: (json['max_amount'] as num).toDouble(),
      rows: json['rows'] as int,
      mode: json['mode'] as String,
      probabilities: probs,
      enabled: json['enabled'] as bool,
    );
  }
}

// Helper parsing method since jsonDecode might need import
dynamic jsonDecode(String source) {
  // Simple custom parser mimicking standard jsonDecode
  return _SimpleJsonParser.decode(source);
}

class _SimpleJsonParser {
  static dynamic decode(String source) {
    source = source.trim();
    if (source.startsWith('[')) {
      final list = source.substring(1, source.length - 1).split(',');
      return list.map((e) => double.tryParse(e.trim()) ?? 0.0).toList();
    } else if (source.startsWith('{')) {
      final Map<String, dynamic> map = {};
      final content = source.substring(1, source.length - 1).trim();
      if (content.isEmpty) return map;
      final parts = content.split(',');
      for (final part in parts) {
        final kv = part.split(':');
        if (kv.length == 2) {
          final k = kv[0].trim().replaceAll('"', '').replaceAll("'", "");
          final v = double.tryParse(kv[1].trim()) ?? 0.0;
          map[k] = v;
        }
      }
      return map;
    }
    return null;
  }
}

class PlinkoPanelView extends StatefulWidget {
  const PlinkoPanelView({super.key});

  @override
  State<PlinkoPanelView> createState() => _PlinkoPanelViewState();
}

class _PlinkoPanelViewState extends State<PlinkoPanelView> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();

  bool _isLoading = false;
  String? _error;

  PlinkoStatsAdmin? _stats;
  PlinkoSettingsAdmin? _settings;
  List<PlinkoLogAdmin> _logs = [];
  List<PlinkoRtpOverride> _rtps = [];

  // Limits controllers
  final _minBetController = TextEditingController();
  final _maxBetController = TextEditingController();
  bool _maintenanceVal = false;

  // Multiplier override screen state
  int _multSelectedRows = 10;
  String _multSelectedRisk = 'medium';
  final List<TextEditingController> _multiplierControllers = [];

  // RTP overrides parameters
  final _rtpMinAmountController = TextEditingController(text: '10');
  final _rtpMaxAmountController = TextEditingController(text: '100');
  int _rtpRows = 10;
  String _rtpRisk = 'medium';
  final List<TextEditingController> _rtpWeightControllers = [];
  bool _rtpEnabled = true;

  @override
  void initState() {
    super.initState();
    _refreshAll();
  }

  @override
  void dispose() {
    _minBetController.dispose();
    _maxBetController.dispose();
    _rtpMinAmountController.dispose();
    _rtpMaxAmountController.dispose();
    _disposeMultiplierControllers();
    _disposeRtpWeightControllers();
    super.dispose();
  }

  void _disposeMultiplierControllers() {
    for (final c in _multiplierControllers) {
      c.dispose();
    }
    _multiplierControllers.clear();
  }

  void _disposeRtpWeightControllers() {
    for (final c in _rtpWeightControllers) {
      c.dispose();
    }
    _rtpWeightControllers.clear();
  }

  // Load standard fallbacks matching backend keys
  List<double> _getFallbackMultipliers(int rows, String risk) {
    final Map<int, Map<String, List<double>>> fallbacks = {
      8: {
        "low": [5.6, 1.6, 1.1, 1.0, 0.5, 1.0, 1.1, 1.6, 5.6],
        "medium": [13.0, 3.0, 1.3, 0.7, 0.4, 0.7, 1.3, 3.0, 13.0],
        "high": [29.0, 4.0, 1.5, 0.3, 0.2, 0.3, 1.5, 4.0, 29.0],
      },
      9: {
        "low": [5.6, 2.0, 1.6, 1.0, 0.7, 0.7, 1.0, 1.6, 2.0, 5.6],
        "medium": [18.0, 4.0, 1.6, 0.9, 0.5, 0.5, 0.9, 1.6, 4.0, 18.0],
        "high": [43.0, 7.0, 2.0, 0.6, 0.2, 0.2, 0.6, 2.0, 7.0, 43.0],
      },
      10: {
        "low": [16.0, 9.0, 2.0, 1.4, 1.1, 1.0, 1.1, 1.4, 2.0, 9.0, 16.0],
        "medium": [22.0, 5.0, 2.0, 1.4, 0.6, 0.4, 0.6, 1.4, 2.0, 5.0, 22.0],
        "high": [110.0, 15.0, 4.0, 1.8, 0.7, 0.3, 0.7, 1.8, 4.0, 15.0, 110.0],
      },
      11: {
        "low": [24.0, 10.0, 3.0, 1.8, 1.2, 1.0, 1.0, 1.2, 1.8, 3.0, 10.0, 24.0],
        "medium": [
          33.0,
          8.0,
          3.0,
          1.6,
          0.7,
          0.5,
          0.5,
          0.7,
          1.6,
          3.0,
          8.0,
          33.0,
        ],
        "high": [
          170.0,
          24.0,
          8.1,
          2.0,
          0.7,
          0.2,
          0.2,
          0.7,
          2.0,
          8.1,
          24.0,
          170.0,
        ],
      },
      12: {
        "low": [
          33.0,
          11.0,
          4.0,
          2.0,
          1.3,
          1.1,
          1.0,
          1.1,
          1.3,
          2.0,
          4.0,
          11.0,
          33.0,
        ],
        "medium": [
          50.0,
          11.0,
          4.0,
          2.0,
          1.1,
          0.6,
          0.3,
          0.6,
          1.1,
          2.0,
          4.0,
          11.0,
          50.0,
        ],
        "high": [
          260.0,
          33.0,
          11.0,
          4.0,
          2.0,
          0.5,
          0.2,
          0.5,
          2.0,
          4.0,
          11.0,
          33.0,
          260.0,
        ],
      },
      13: {
        "low": [
          43.0,
          13.0,
          6.0,
          3.0,
          1.3,
          1.2,
          1.0,
          1.0,
          1.2,
          1.3,
          3.0,
          6.0,
          13.0,
          43.0,
        ],
        "medium": [
          76.0,
          14.0,
          6.0,
          3.0,
          1.3,
          0.7,
          0.4,
          0.4,
          0.7,
          1.3,
          3.0,
          6.0,
          14.0,
          76.0,
        ],
        "high": [
          420.0,
          56.0,
          18.0,
          6.0,
          3.0,
          1.0,
          0.2,
          0.2,
          1.0,
          3.0,
          6.0,
          18.0,
          56.0,
          420.0,
        ],
      },
      14: {
        "low": [
          56.0,
          18.0,
          8.0,
          3.8,
          2.0,
          1.2,
          1.0,
          1.0,
          1.0,
          1.2,
          2.0,
          3.8,
          8.0,
          18.0,
          56.0,
        ],
        "medium": [
          110.0,
          18.0,
          8.0,
          3.8,
          1.5,
          1.0,
          0.5,
          0.2,
          0.5,
          1.0,
          1.5,
          3.8,
          8.0,
          18.0,
          110.0,
        ],
        "high": [
          620.0,
          83.0,
          27.0,
          8.0,
          3.0,
          1.3,
          0.5,
          0.2,
          0.5,
          1.3,
          3.0,
          8.0,
          27.0,
          83.0,
          620.0,
        ],
      },
      15: {
        "low": [
          79.0,
          24.0,
          10.0,
          4.8,
          2.5,
          1.5,
          1.0,
          1.0,
          1.0,
          1.0,
          1.5,
          2.5,
          4.8,
          10.0,
          24.0,
          79.0,
        ],
        "medium": [
          180.0,
          29.0,
          11.0,
          5.0,
          2.0,
          1.1,
          0.6,
          0.3,
          0.3,
          0.6,
          1.1,
          2.0,
          5.0,
          11.0,
          29.0,
          180.0,
        ],
        "high": [
          1000.0,
          130.0,
          37.0,
          11.0,
          4.0,
          1.5,
          1.0,
          0.5,
          0.5,
          1.0,
          1.5,
          4.0,
          11.0,
          37.0,
          130.0,
          1000.0,
        ],
      },
      16: {
        "low": [
          110.0,
          33.0,
          12.0,
          6.0,
          3.0,
          1.8,
          1.2,
          1.0,
          1.0,
          1.0,
          1.2,
          1.8,
          3.0,
          6.0,
          12.0,
          33.0,
          110.0,
        ],
        "medium": [
          260.0,
          43.0,
          15.0,
          6.0,
          3.0,
          1.5,
          1.0,
          0.5,
          0.3,
          0.5,
          1.0,
          1.5,
          3.0,
          6.0,
          15.0,
          43.0,
          260.0,
        ],
        "high": [
          1000.0,
          130.0,
          43.0,
          14.0,
          5.0,
          2.0,
          1.3,
          0.5,
          0.2,
          0.5,
          1.3,
          2.0,
          5.0,
          14.0,
          43.0,
          130.0,
          1000.0,
        ],
      },
    };
    return fallbacks[rows]?[risk] ?? List.filled(rows + 1, 1.0);
  }

  void _initializeMultiplierInputs() {
    _disposeMultiplierControllers();
    final List<double> mList = _getFallbackMultipliers(
      _multSelectedRows,
      _multSelectedRisk,
    );
    for (final val in mList) {
      _multiplierControllers.add(TextEditingController(text: val.toString()));
    }
  }

  void _initializeRtpWeightInputs() {
    _disposeRtpWeightControllers();
    // Default weights map: symmetric weight mirroring binomial
    final double step = 100.0 / (_rtpRows + 1);
    for (int i = 0; i <= _rtpRows; i++) {
      _rtpWeightControllers.add(
        TextEditingController(text: step.toStringAsFixed(1)),
      );
    }
  }

  Future<void> _refreshAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final statsResponse = await _apiClient.dio.get('/admin/plinko/stats');
      final settingsResponse = await _apiClient.dio.get(
        '/admin/plinko/settings',
      );
      final logsResponse = await _apiClient.dio.get('/admin/plinko/logs');
      final rtpResponse = await _apiClient.dio.get('/admin/plinko/rtp');

      final stats = PlinkoStatsAdmin.fromJson(statsResponse.data);
      final settings = PlinkoSettingsAdmin.fromJson(settingsResponse.data);
      final logs = (logsResponse.data as List)
          .map((json) => PlinkoLogAdmin.fromJson(json))
          .toList();
      final rtps = (rtpResponse.data as List)
          .map((json) => PlinkoRtpOverride.fromJson(json))
          .toList();

      setState(() {
        _stats = stats;
        _settings = settings;
        _logs = logs;
        _rtps = rtps;
        _isLoading = false;

        // Initialize general limits inputs
        _minBetController.text = settings.minBet.toString();
        _maxBetController.text = settings.maxBet.toString();
        _maintenanceVal = settings.maintenanceMode;
      });

      _initializeMultiplierInputs();
      _initializeRtpWeightInputs();
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _error =
            e.response?.data['detail'] ??
            e.message ??
            'Unknown network failure';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _updateLimits() async {
    final minBet = double.tryParse(_minBetController.text) ?? 10.0;
    final maxBet = double.tryParse(_maxBetController.text) ?? 5000.0;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiClient.dio.post(
        '/admin/plinko/settings',
        data: {
          'min_bet': minBet,
          'max_bet': maxBet,
          'maintenance_mode': _maintenanceVal,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Plinko limits updated successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );
      setState(() {
        _settings = PlinkoSettingsAdmin.fromJson(response.data);
        _isLoading = false;
      });
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data['detail'] ?? 'Failed to update limits',
          ),
          backgroundColor: AdminTheme.error,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateMultipliers() async {
    final List<double> mList = [];
    for (final c in _multiplierControllers) {
      mList.add(double.tryParse(c.text) ?? 1.0);
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.post(
        '/admin/plinko/multipliers',
        data: {
          'rows': _multSelectedRows,
          'mode': _multSelectedRisk,
          'multipliers_json': mList.toString(),
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Multipliers override saved successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data['detail'] ?? 'Failed to update multipliers',
          ),
          backgroundColor: AdminTheme.error,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _addRtpOverride() async {
    final minAmt = double.tryParse(_rtpMinAmountController.text) ?? 10.0;
    final maxAmt = double.tryParse(_rtpMaxAmountController.text) ?? 100.0;

    // Construct probability JSON: map index to percentage
    final Map<String, double> probs = {};
    double totalWeight = 0.0;
    for (int i = 0; i <= _rtpRows; i++) {
      final weight = double.tryParse(_rtpWeightControllers[i].text) ?? 0.0;
      probs[i.toString()] = weight;
      totalWeight += weight;
    }

    if (totalWeight < 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total probability weight cannot be zero'),
          backgroundColor: AdminTheme.error,
        ),
      );
      return;
    }

    // Convert weights to percentage summing to 100
    final Map<String, double> normalizedProbs = {};
    probs.forEach((key, val) {
      normalizedProbs[key] = (val / totalWeight) * 100.0;
    });

    // Generate JSON
    final List<String> jsonParts = [];
    normalizedProbs.forEach((k, v) {
      jsonParts.add('"$k":${v.toStringAsFixed(2)}');
    });
    final jsonStr = '{${jsonParts.join(',')}}';

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.post(
        '/admin/plinko/rtp',
        data: {
          'min_amount': minAmt,
          'max_amount': maxAmt,
          'rows': _rtpRows,
          'mode': _rtpRisk,
          'probability_json': jsonStr,
          'enabled': _rtpEnabled,
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('RTP Override tier added successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );
      _refreshAll();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data['detail'] ?? 'Failed to add RTP override',
          ),
          backgroundColor: AdminTheme.error,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteRtpOverride(int id) async {
    setState(() {
      _isLoading = true;
    });
    try {
      await _apiClient.dio.delete('/admin/plinko/rtp/$id');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Override rule deleted successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );
      _refreshAll();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data['detail'] ?? 'Failed to delete override',
          ),
          backgroundColor: AdminTheme.error,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
    );

    if (_isLoading && _stats == null) {
      return const Center(
        child: CircularProgressIndicator(color: AdminTheme.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 50,
                color: AdminTheme.error,
              ),
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
              'Plinko Originals Controller',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AdminTheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Statistics panel
            if (_stats != null) ...[
              _buildStatsCardGrid(_stats!, currencyFormatter),
              const SizedBox(height: 20),
            ],

            // Limits Form
            _buildConfigurationPanel(),
            const SizedBox(height: 20),

            // Multipliers override grid
            _buildMultiplierOverridePanel(),
            const SizedBox(height: 20),

            // RTP overrides list & form
            _buildRtpOverridesPanel(),
            const SizedBox(height: 24),

            // Log tables
            const Text(
              'Recent Plinko Stakes Logs',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AdminTheme.textMain,
              ),
            ),
            const SizedBox(height: 12),
            _buildLogsList(currencyFormatter),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCardGrid(
    PlinkoStatsAdmin stats,
    NumberFormat currencyFormatter,
  ) {
    final bool isWide = MediaQuery.of(context).size.width > 800;
    if (isWide) {
      return Row(
        children: [
          Expanded(
            child: _buildStatCard(
              title: 'Stakes Placed',
              value: stats.totalGames.toString(),
              icon: Icons.casino_outlined,
              color: AdminTheme.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'Bets Volume',
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
              title: 'Net Profit',
              value: currencyFormatter.format(stats.platformNetProfit),
              icon: Icons.account_balance_wallet_outlined,
              color: stats.platformNetProfit >= 0
                  ? AdminTheme.success
                  : AdminTheme.error,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              title: 'RTP Ratio',
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
                  title: 'Stakes Placed',
                  value: stats.totalGames.toString(),
                  icon: Icons.casino_outlined,
                  color: AdminTheme.info,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  title: 'Bets Volume',
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
                  title: 'Net Profit',
                  value: currencyFormatter.format(stats.platformNetProfit),
                  icon: Icons.account_balance_wallet_outlined,
                  color: stats.platformNetProfit >= 0
                      ? AdminTheme.success
                      : AdminTheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  title: 'RTP Ratio',
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
                  Text(
                    title,
                    style: const TextStyle(
                      color: AdminTheme.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AdminTheme.textMain,
                    ),
                  ),
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AdminTheme.textMain,
                    ),
                  ),
                ],
              ),
              const Divider(color: AdminTheme.borderColor, height: 24),
              TextFormField(
                controller: _minBetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimum Bet Limit (INR)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _maxBetController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Maximum Bet Limit (INR)',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeColor: AdminTheme.error,
                title: const Text(
                  'Maintenance Mode',
                  style: TextStyle(fontSize: 14, color: AdminTheme.textMain),
                ),
                subtitle: const Text(
                  'Prevent players from placing Plinko stakes',
                  style: TextStyle(fontSize: 12, color: AdminTheme.textMuted),
                ),
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
                onPressed: _updateLimits,
                child: const Text(
                  'SAVE LIMITS CONFIG',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMultiplierOverridePanel() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.grid_on, color: AdminTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Override Bucket Multipliers',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AdminTheme.textMain,
                  ),
                ),
              ],
            ),
            const Divider(color: AdminTheme.borderColor, height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _multSelectedRows,
                    decoration: const InputDecoration(labelText: 'Rows'),
                    dropdownColor: AdminTheme.surface,
                    items: List.generate(9, (i) => 8 + i)
                        .map(
                          (rows) => DropdownMenuItem<int>(
                            value: rows,
                            child: Text('$rows Rows'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _multSelectedRows = val;
                        });
                        _initializeMultiplierInputs();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _multSelectedRisk,
                    decoration: const InputDecoration(labelText: 'Risk'),
                    dropdownColor: AdminTheme.surface,
                    items: ['low', 'medium', 'high']
                        .map(
                          (risk) => DropdownMenuItem<String>(
                            value: risk,
                            child: Text(
                              risk.substring(0, 1).toUpperCase() +
                                  risk.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _multSelectedRisk = val;
                        });
                        _initializeMultiplierInputs();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Specify multipliers for each bucket (left-to-right):',
              style: TextStyle(fontSize: 12, color: AdminTheme.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_multiplierControllers.length, (index) {
                return SizedBox(
                  width: 68,
                  child: TextField(
                    controller: _multiplierControllers[index],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'B$index',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primary,
                foregroundColor: AdminTheme.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _updateMultipliers,
              child: const Text(
                'SAVE MULTIPLIERS OVERRIDE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
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
                Icon(Icons.psychology, color: AdminTheme.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'RTP Probability Weight Overrides',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AdminTheme.textMain,
                  ),
                ),
              ],
            ),
            const Divider(color: AdminTheme.borderColor, height: 24),

            // Active rules list
            if (_rtps.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: Text(
                  'No active custom RTP profiles.',
                  style: TextStyle(color: AdminTheme.textMuted, fontSize: 12),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rtps.length,
                itemBuilder: (context, index) {
                  final rtp = _rtps[index];
                  return Card(
                    color: Colors.white.withOpacity(0.02),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bets: ₹${rtp.minAmount.toInt()} - ₹${rtp.maxAmount.toInt()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AdminTheme.textMain,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Game: ${rtp.rows} Rows (${rtp.mode.toUpperCase()}) | Enabled: ${rtp.enabled}',
                                  style: const TextStyle(
                                    color: AdminTheme.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AdminTheme.error,
                              size: 20,
                            ),
                            onPressed: () => _deleteRtpOverride(rtp.id),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),
            const Text(
              'Add New RTP Override Tier:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AdminTheme.textMain,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rtpMinAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Min Bet (INR)',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _rtpMaxAmountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Bet (INR)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _rtpRows,
                    decoration: const InputDecoration(labelText: 'Rows'),
                    dropdownColor: AdminTheme.surface,
                    items: List.generate(9, (i) => 8 + i)
                        .map(
                          (rows) => DropdownMenuItem<int>(
                            value: rows,
                            child: Text('$rows Rows'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _rtpRows = val;
                        });
                        _initializeRtpWeightInputs();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _rtpRisk,
                    decoration: const InputDecoration(labelText: 'Risk'),
                    dropdownColor: AdminTheme.surface,
                    items: ['low', 'medium', 'high']
                        .map(
                          (risk) => DropdownMenuItem<String>(
                            value: risk,
                            child: Text(
                              risk.substring(0, 1).toUpperCase() +
                                  risk.substring(1),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _rtpRisk = val;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Specify Landing Probability Weights (%):',
              style: TextStyle(fontSize: 12, color: AdminTheme.textMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_rtpWeightControllers.length, (index) {
                return SizedBox(
                  width: 68,
                  child: TextField(
                    controller: _rtpWeightControllers[index],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'P$index',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 4,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.primary,
                foregroundColor: AdminTheme.background,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _addRtpOverride,
              child: const Text(
                'CREATE RTP RULE',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
            child: Text(
              'No Plinko stakes logged yet.',
              style: TextStyle(color: AdminTheme.textMuted),
            ),
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
        final isWin = log.winAmount > log.betAmount;

        final timeStr = DateFormat.yMMMd().add_jm().format(log.createdAt);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor:
                      (isWin ? AdminTheme.success : AdminTheme.warning)
                          .withOpacity(0.1),
                  child: Icon(
                    isWin ? Icons.trending_up : Icons.trending_flat,
                    color: isWin ? AdminTheme.success : AdminTheme.warning,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.userName != null
                            ? '${log.userName} (${log.userPhone})'
                            : log.userPhone,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: AdminTheme.textMain,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bet: ${currencyFormatter.format(log.betAmount)} | ${log.rows} Rows (${log.mode.toUpperCase()}) | Win Prob: ${log.winProbability != null ? '${(log.winProbability! * 100).toStringAsFixed(2)}%' : '-'}',
                        style: const TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: AdminTheme.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isWin ? "+" : ""}${currencyFormatter.format(log.winAmount)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isWin ? AdminTheme.success : AdminTheme.textMain,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${log.multiplier.toStringAsFixed(2)}x',
                      style: const TextStyle(
                        color: AdminTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
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
