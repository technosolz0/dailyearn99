import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import '../bloc/word_puzzle_bloc.dart';
import '../models/word_puzzle_models.dart';
import '../repository/word_puzzle_repository.dart';
import 'word_game_screen.dart';

class WordLobbyScreen extends StatefulWidget {
  const WordLobbyScreen({Key? key}) : super(key: key);

  @override
  State<WordLobbyScreen> createState() => _WordLobbyScreenState();
}

class _WordLobbyScreenState extends State<WordLobbyScreen> {
  late final WordPuzzleRepository _repository;
  List<WordContestModel> _contests = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = WordPuzzleRepository(getIt<ApiClient>());
    _refreshContests();
  }

  Future<void> _refreshContests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final list = await _repository.fetchWordContests();
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
      backgroundColor: const Color(0xFF0F0C20),
      appBar: AppBar(
        title: const Text(
          'WORD PUZZLE CHALLENGE',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 15,
          ),
        ),
        backgroundColor: const Color(0xFF151030),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshContests,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8A2BE2)),
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
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8A2BE2)),
                        ),
                      ],
                    ),
                  ),
                )
              : _contests.isEmpty
                  ? const Center(
                      child: Text(
                        'No word challenges listed currently.',
                        style: TextStyle(color: Colors.white54),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refreshContests,
                      color: const Color(0xFF8A2BE2),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _contests.length,
                        itemBuilder: (context, index) {
                          return _buildContestCard(context, _contests[index]);
                        },
                      ),
                    ),
    );
  }

  Widget _buildContestCard(BuildContext context, WordContestModel contest) {
    bool isActive = contest.status == 'ACTIVE';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF151030),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF8A2BE2).withOpacity(0.8) : Colors.white12,
          width: isActive ? 1.5 : 1.0,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF8A2BE2).withOpacity(0.1),
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
              color: const Color(0xFF1A143B),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: contest.difficulty == 'HARD'
                          ? Colors.red[800]
                          : contest.difficulty == 'MEDIUM'
                              ? Colors.amber[700]
                              : Colors.green[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      contest.difficulty,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
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
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8A2BE2)),
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _enterGame(context, contest),
                    child: const Text(
                      'JOIN CHALLENGE',
                      style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8A2BE2),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
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

  void _enterGame(BuildContext context, WordContestModel contest) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BlocProvider(
          create: (context) => WordPuzzleBloc(_repository)..add(
            JoinWordContestEvent(contest.id),
          ),
          child: WordGameScreen(
            contestId: contest.id,
            title: contest.title,
          ),
        ),
      ),
    ).then((_) => _refreshContests());
  }
}
