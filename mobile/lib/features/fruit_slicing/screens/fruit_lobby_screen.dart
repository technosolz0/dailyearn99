import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/features/contest/game_leaderboard_screen.dart';
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
  List<FruitContestModel> _contests = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = FruitRepository(getIt<ApiClient>());
    _refreshContests();
  }

  Future<void> _refreshContests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _repository.fetchFruitContests();
      setState(() {
        _contests = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0A1B),
      appBar: AppBar(
        title: const Text(
          'FRUIT TOURNAMENTS',
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
            onPressed: _refreshContests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, appState) {
          final user = appState.currentUser;
          
          return _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF4500)),
                )
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _refreshContests,
                              child: const Text('Retry'),
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF4500)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _contests.isEmpty
                      ? const Center(
                          child: Text(
                            'No fruit tournaments listed currently.',
                            style: TextStyle(color: Colors.white54),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _refreshContests,
                          color: const Color(0xFFFF4500),
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _contests.length,
                            itemBuilder: (context, index) {
                              return _buildContestCard(context, _contests[index], user);
                            },
                          ),
                        );
        },
      ),
    );
  }

  Widget _buildContestCard(BuildContext context, FruitContestModel contest, dynamic user) {
    bool isActive = contest.status == 'ACTIVE';
    
    // Check user registration status
    final isJoined = user?.joinedFruitContestIds?.contains(contest.id) ?? false;
    final isCompleted = user?.completedFruitContestIds?.contains(contest.id) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF13102C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFFFF4500).withOpacity(0.8) : Colors.white12,
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFFF4500).withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1C183B),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      contest.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4500).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFF4500), width: 1),
                        ),
                        child: const Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Color(0xFFFF4500),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Standalone Leaderboard button to check standings easily
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.emoji_events, color: Colors.amberAccent, size: 20),
                        tooltip: 'View Standings',
                        onPressed: () => _openLeaderboard(context, contest),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoColumn('PRIZE POOL', '₹${contest.prizePool.toStringAsFixed(0)}', Colors.cyanAccent),
                      _buildInfoColumn('ENTRY FEE', '₹${contest.entryFee.toStringAsFixed(0)}', Colors.greenAccent),
                      _buildInfoColumn('LIMIT TIME', '${contest.durationSeconds}s', Colors.amberAccent),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Slots: ${contest.joinedSlots}/${contest.totalSlots}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      if (isCompleted)
                        const Text(
                          'COMPLETED',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold),
                        )
                      else if (isJoined)
                        const Text(
                          'REGISTERED',
                          style: TextStyle(color: Color(0xFFFF4500), fontSize: 11, fontWeight: FontWeight.bold),
                        )
                      else
                        Text(
                          'Status: ${contest.status}',
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: contest.totalSlots > 0 ? contest.joinedSlots / contest.totalSlots : 0,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF4500)),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 16),
                  
                  // CTA button depending on registration & play status
                  if (isCompleted)
                    ElevatedButton.icon(
                      onPressed: () => _openLeaderboard(context, contest),
                      icon: const Icon(Icons.emoji_events),
                      label: const Text('LEADERBOARD / STANDINGS'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber[700],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                  else if (isJoined)
                    ElevatedButton.icon(
                      onPressed: () => _startGamePlay(context, contest),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('PLAY TOURNAMENT NOW'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => _showJoinConfirmation(context, contest),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF4500),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'JOIN TOURNAMENT (₹${contest.entryFee.toStringAsFixed(0)})',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
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

  Widget _buildInfoColumn(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 8, letterSpacing: 0.8),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showJoinConfirmation(BuildContext context, FruitContestModel contest) {
    final double userBalance = context.read<AppBloc>().state.currentUser?.totalBalance ?? 0.0;
    final bool canAfford = userBalance >= contest.entryFee;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13102C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Confirm Registration',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  contest.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Entry Fee', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    Text('₹${contest.entryFee.toStringAsFixed(0)}', style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Your Wallet Balance', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    Text('₹${userBalance.toStringAsFixed(2)}', style: TextStyle(color: canAfford ? Colors.cyanAccent : Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 24),
                if (!canAfford) ...[
                  const Text(
                    'Insufficient balance. Please deposit funds first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.redAccent, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('CANCEL'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white60,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !canAfford
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                _joinContestAndPlay(context, contest);
                              },
                        child: const Text('CONFIRM & JOIN'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF4500),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
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

  Future<void> _joinContestAndPlay(BuildContext context, FruitContestModel contest) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF4500))),
    );

    try {
      // 1. Join contest via repository to deduct fee cleanly
      await _repository.joinFruitContest(contest.id);
      
      // 2. Refresh global AppBloc user details for balance update
      if (context.mounted) {
        context.read<AppBloc>().add(LoadProfileEvent());
        Navigator.pop(context); // Close loading spinner
        
        // 3. Start game
        _startGamePlay(context, contest);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _startGamePlay(BuildContext context, FruitContestModel contest) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => FruitGameBloc(_repository)..add(
            LoadFruitGameEvent(contest.id),
          ),
          child: TournamentGameScreen(
            contestId: contest.id,
            title: contest.title,
          ),
        ),
      ),
    ).then((_) {
      _refreshContests();
      context.read<AppBloc>().add(LoadProfileEvent());
    });
  }

  void _openLeaderboard(BuildContext context, FruitContestModel contest) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameLeaderboardScreen(
          contestId: contest.id,
          title: contest.title,
          gameType: 'fruit',
          entryFee: contest.entryFee,
          prizePool: contest.prizePool,
        ),
      ),
    );
  }
}
