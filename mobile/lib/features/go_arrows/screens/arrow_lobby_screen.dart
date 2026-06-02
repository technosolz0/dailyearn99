import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/features/app_bloc.dart';
import 'package:dailyearn99/features/contest/game_leaderboard_screen.dart';
import '../bloc/arrow_bloc.dart';
import '../models/arrow_models.dart';
import '../repository/arrow_repository.dart';
import 'arrow_game_screen.dart';

class ArrowLobbyScreen extends StatefulWidget {
  const ArrowLobbyScreen({super.key});

  @override
  State<ArrowLobbyScreen> createState() => _ArrowLobbyScreenState();
}

class _ArrowLobbyScreenState extends State<ArrowLobbyScreen> {
  late final ArrowRepository _repository;
  List<ArrowContestModel> _contests = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = ArrowRepository(getIt<ApiClient>());
    _refreshContests();
  }

  Future<void> _refreshContests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _repository.fetchArrowContests();
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
      backgroundColor: const Color(0xFF0C091A),
      appBar: AppBar(
        title: const Text(
          '🏹 GO ARROWS CHALLENGE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 14,
          ),
        ),
        backgroundColor: const Color(0xFF140F2D),
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
                  child: CircularProgressIndicator(color: Color(0xFFFF9900)),
                )
              : _error != null
              ? Center(
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
                          onPressed: _refreshContests,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF9900),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _contests.isEmpty
              ? const Center(
                  child: Text(
                    'No arrow challenges listed currently.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _refreshContests,
                  color: const Color(0xFFFF9900),
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

  Widget _buildContestCard(
    BuildContext context,
    ArrowContestModel contest,
    dynamic user,
  ) {
    bool isActive = contest.status == 'ACTIVE';

    final isJoined = user?.joinedArrowContestIds?.contains(contest.id) ?? false;
    final isCompleted = user?.completedArrowContestIds?.contains(contest.id) ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF140F2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? const Color(0xFFFF9900).withOpacity(0.8)
              : Colors.white12,
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFFFF9900).withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            // Header Image/Design
            Stack(
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF2E1500),
                        Color(0xFF140F2D),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Icon(
                    Icons.double_arrow_rounded,
                    color: Colors.white10,
                    size: 80,
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.green[800]
                              : Colors.amber[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          contest.status,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.emoji_events,
                          color: Colors.amberAccent,
                          size: 20,
                        ),
                        tooltip: 'View Standings',
                        onPressed: () => _openLeaderboard(context, contest),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 16,
                  right: 16,
                  child: Text(
                    contest.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoColumn(
                        'PRIZE POOL',
                        '₹${contest.prizePool.toStringAsFixed(0)}',
                        Colors.cyanAccent,
                      ),
                      _buildInfoColumn(
                        'ENTRY FEE',
                        '₹${contest.entryFee.toStringAsFixed(0)}',
                        Colors.greenAccent,
                      ),
                      _buildInfoColumn(
                        'GRID SIZE',
                        '${contest.gridSize}x${contest.gridSize}',
                        Colors.amberAccent,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Slots: ${contest.joinedSlots}/${contest.totalSlots}',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                      if (isCompleted)
                        const Text(
                          'COMPLETED',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else if (isJoined)
                        const Text(
                          'IN PROGRESS',
                          style: TextStyle(
                            color: Color(0xFFFF9900),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      else
                        Text(
                          'Play Time: ${contest.durationSeconds}s',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: contest.totalSlots > 0
                        ? contest.joinedSlots / contest.totalSlots
                        : 0,
                    backgroundColor: Colors.white12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFFFF9900),
                    ),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 16),

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
                    if (isActive)
                      ElevatedButton.icon(
                        onPressed: () => _startGamePlay(context, contest),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('PLAY CHALLENGE NOW'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9900),
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(
                              Icons.lock_clock,
                              color: Colors.white38,
                            ),
                            label: Text(
                              'STARTS AT ${contest.startTime.toLocal().hour.toString().padLeft(2, '0')}:${contest.startTime.toLocal().minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                              disabledBackgroundColor: Colors.white12,
                              minimumSize: const Size(double.infinity, 44),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Aapne register kar liya hai! Challenge start hone ka wait karein.',
                            style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                  else
                    ElevatedButton(
                      onPressed: () => _showJoinConfirmation(context, contest),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9900),
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'JOIN CHALLENGE (₹${contest.entryFee.toStringAsFixed(0)})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
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
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 8,
            letterSpacing: 0.8,
          ),
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

  void _showJoinConfirmation(BuildContext context, ArrowContestModel contest) {
    final double userBalance =
        context.read<AppBloc>().state.currentUser?.totalBalance ?? 0.0;
    final bool canAfford = userBalance >= contest.entryFee;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140F2D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return SafeArea(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(24.0),
                child: Column(
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
                    const SizedBox(height: 12),
                    Text(
                      contest.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rules Container
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.gavel_rounded,
                                color: Color(0xFFFF9900),
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'GAMEPLAY RULES',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          RichText(
                            text: const TextSpan(
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11.5,
                                height: 1.5,
                                fontFamily: 'sans-serif',
                              ),
                              children: [
                                TextSpan(
                                  text: '• Go Arrows gameplay: ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      'Tapped blocks fly off in their arrow directions if their path is completely unobstructed by other blocks.\n',
                                ),
                                TextSpan(
                                  text: '• Score Formula: ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      'Score = 10000 - (Seconds × 8) - (Taps × 4). Fewer taps and faster clearing times yield higher scores. Obstruction taps decrease your score!\n',
                                ),
                                TextSpan(
                                  text: '• Anti-Cheat Validation: ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      'Successive moves must have at least a 50ms interval. Quick rapid-fire bot patterns, macros, and clickers are auto-disqualified.',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Entry Fee',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        Text(
                          '₹${contest.entryFee.toStringAsFixed(0)}',
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Wallet Balance',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                        Text(
                          '₹${userBalance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: canAfford
                               ? Colors.cyanAccent
                               : Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
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
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white60,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('CANCEL'),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF9900),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('CONFIRM & JOIN'),
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
      },
    );
  }

  Future<void> _joinContestAndPlay(
    BuildContext context,
    ArrowContestModel contest,
  ) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF9900)),
      ),
    );

    try {
      await _repository.startArrowSession(contest.id);

      if (context.mounted) {
        context.read<AppBloc>().add(LoadProfileEvent());
        Navigator.pop(context); // Close loading spinner

        _startGamePlay(context, contest);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _startGamePlay(BuildContext context, ArrowContestModel contest) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => BlocProvider(
              create: (context) =>
                  ArrowBloc(_repository)..add(LoadArrowGameEvent(contest.id)),
              child: ArrowGameScreen(
                contestId: contest.id,
                title: contest.title,
              ),
            ),
          ),
        )
        .then((_) {
          _refreshContests();
          context.read<AppBloc>().add(LoadProfileEvent());
        });
  }

  void _openLeaderboard(BuildContext context, ArrowContestModel contest) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameLeaderboardScreen(
          contestId: contest.id,
          title: contest.title,
          gameType: 'arrow',
          entryFee: contest.entryFee,
          prizePool: contest.prizePool,
        ),
      ),
    );
  }
}
