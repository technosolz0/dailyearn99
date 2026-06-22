import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/core/widgets/custom_button.dart';
import '../bloc/fruit_game_bloc.dart';
import '../models/fruit_models.dart';
import '../repository/fruit_repository.dart';
import 'tournament_game_screen.dart';

class FruitLobbyScreen extends StatefulWidget {
  const FruitLobbyScreen({Key? key}) : super(key: key);

  @override
  State<FruitLobbyScreen> createState() => _FruitLobbyScreenState();
}

class _FruitLobbyScreenState extends State<FruitLobbyScreen> {
  late final FruitRepository _repository;
  FruitSettingsModel? _settings;
  List<FruitGameModel> _history = [];
  bool _isLoading = false;
  String? _error;
  final TextEditingController _betController = TextEditingController(text: '10');

  @override
  void initState() {
    super.initState();
    _repository = FruitRepository(getIt<ApiClient>());
    _refreshData();
  }

  @override
  void dispose() {
    _betController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final settings = await _repository.fetchFruitSettings();
      final history = await _repository.fetchFruitHistory();
      setState(() {
        _settings = settings;
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _startGamePlay(BuildContext context, double bet) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => BlocProvider(
              create: (context) => FruitGameBloc(_repository)
                ..add(LoadFruitSettingsEvent())
                ..add(StartFruitGameEvent(bet)),
              child: const TournamentGameScreen(
                title: 'Fruit Slicing',
              ),
            ),
          ),
        )
        .then((_) {
          _refreshData();
          context.read<AppBloc>().add(LoadProfileEvent());
        });
  }

  void _validateAndStart() {
    if (_settings == null) return;
    
    if (_settings!.maintenanceMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Game is currently under maintenance. Please try again later.'),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    final double? bet = double.tryParse(_betController.text);
    if (bet == null || bet <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid bet amount.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (bet < _settings!.minBet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Minimum bet is ₹${_settings!.minBet.toStringAsFixed(2)}.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (bet > _settings!.maxBet) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum bet is ₹${_settings!.maxBet.toStringAsFixed(2)}.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final double userBalance =
        context.read<AppBloc>().state.currentUser?.totalBalance ?? 0.0;
    if (bet > userBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient balance. Please deposit funds.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _startGamePlay(context, bet);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A1B),
      appBar: AppBar(
        title: const Text(
          'FRUIT CASINO',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            fontSize: 15,
          ),
        ),
        backgroundColor: const Color(0xFF13102C),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, appState) {
          final user = appState.currentUser;
          final double userBalance = user?.totalBalance ?? 0.0;

          if (_isLoading && _settings == null) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF4500)),
            );
          }

          if (_error != null && _settings == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshData,
                      child: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4500),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Balance Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1F1B4E), Color(0xFF13102C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'YOUR WALLET BALANCE',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '₹${userBalance.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4500).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Color(0xFFFF4500),
                          size: 24,
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Maintenance Block banner if locked
                if (_settings?.maintenanceMode ?? false) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'System Maintenance Mode: The Fruit Slicing casino is locked temporarily.',
                            style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 2. Betting Section Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13102C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'PLACE YOUR BET',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _betController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                prefixText: '₹ ',
                                prefixStyle: const TextStyle(
                                  color: Colors.greenAccent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                filled: true,
                                fillColor: const Color(0xFF0C0A1B),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFFF4500)),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildQuickBetButton('Min', () {
                            if (_settings != null) {
                              _betController.text = _settings!.minBet.toStringAsFixed(0);
                            }
                          }),
                          _buildQuickBetButton('1/2', () {
                            final current = double.tryParse(_betController.text) ?? 10.0;
                            final next = max(current / 2, _settings?.minBet ?? 10.0);
                            _betController.text = next.toStringAsFixed(0);
                          }),
                          _buildQuickBetButton('2x', () {
                            final current = double.tryParse(_betController.text) ?? 10.0;
                            final next = min(current * 2, _settings?.maxBet ?? 50000.0);
                            _betController.text = next.toStringAsFixed(0);
                          }),
                          _buildQuickBetButton('Max', () {
                            if (_settings != null) {
                              _betController.text = min(_settings!.maxBet, userBalance).toStringAsFixed(0);
                            }
                          }),
                        ],
                      ),
                      const SizedBox(height: 20),
                      CustomButton(
                        text: 'START GAME',
                        onPressed: (_settings?.maintenanceMode ?? false) ? null : _validateAndStart,
                        backgroundColor: const Color(0xFFFF4500),
                        foregroundColor: Colors.white,
                        height: 50,
                        borderRadius: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Fruit Multipliers Details
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13102C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.cyanAccent, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'GAMEPLAY MULTIPLIERS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Slice fruits/vegetables to accumulate multiplier scale. Tap Cash Out to secure your winnings. Hitting a bomb causes instant loss. Missing items drops multiplier.',
                        style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      if (_settings != null) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _settings!.getParsedMultipliers().entries.map((entry) {
                            final bool isMiss = entry.key == 'miss';
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isMiss 
                                    ? Colors.redAccent.withOpacity(0.1)
                                    : Colors.cyanAccent.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isMiss
                                      ? Colors.redAccent.withOpacity(0.3)
                                      : Colors.cyanAccent.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    entry.key.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isMiss ? '-${entry.value.abs()}x' : '+${entry.value}x',
                                    style: TextStyle(
                                      color: isMiss ? Colors.redAccent : Colors.cyanAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 4. Play History Logs
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF13102C),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'RECENT GAMES HISTORY',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_history.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Text(
                              'No gameplay history available yet.',
                              style: TextStyle(color: Colors.white30, fontSize: 12),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _history.length,
                          separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.04)),
                          itemBuilder: (context, index) {
                            final log = _history[index];
                            final bool isWon = log.status == 'WON';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Game #${log.id}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Bet: ₹${log.betAmount.toStringAsFixed(0)} | Scale: ${log.currentMultiplier.toStringAsFixed(2)}x',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        isWon ? '+₹${log.winAmount.toStringAsFixed(2)}' : '₹0.00',
                                        style: TextStyle(
                                          color: isWon ? Colors.greenAccent : Colors.redAccent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isWon 
                                              ? Colors.greenAccent.withOpacity(0.1)
                                              : Colors.redAccent.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          log.status,
                                          style: TextStyle(
                                            color: isWon ? Colors.greenAccent : Colors.redAccent,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickBetButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1C183B),
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
