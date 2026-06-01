import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';
import 'package:dailyearn99/core/network/api_client.dart';
import 'package:dailyearn99/core/utils/dependency_injection.dart';
import 'package:dailyearn99/core/constants/api_constants.dart';
import 'package:dailyearn99/core/network/secure_storage_service.dart';

class GameLeaderboardItem {
  final int userId;
  final String name;
  final int score;
  final int rank;
  final double? completionTime;
  final int? maxCombo;
  final int? missCount;
  final double? prizeAmount;

  GameLeaderboardItem({
    required this.userId,
    required this.name,
    required this.score,
    required this.rank,
    this.completionTime,
    this.maxCombo,
    this.missCount,
    this.prizeAmount,
  });

  factory GameLeaderboardItem.fromJson(Map<String, dynamic> json, String gameType) {
    double? timeVal;
    if (json.containsKey('completion_time_seconds')) {
      timeVal = (json['completion_time_seconds'] as num?)?.toDouble();
    } else if (json.containsKey('completion_seconds')) {
      timeVal = (json['completion_seconds'] as num?)?.toDouble();
    }

    return GameLeaderboardItem(
      userId: json['user_id'] as int,
      name: json['name'] as String? ?? 'Player',
      score: json['score'] as int? ?? 0,
      rank: json['rank'] as int? ?? 0,
      completionTime: timeVal,
      maxCombo: json['max_combo'] as int?,
      missCount: json['miss_count'] as int?,
      prizeAmount: (json['prize_amount'] as num?)?.toDouble(),
    );
  }
}

class GameLeaderboardScreen extends StatefulWidget {
  final int contestId;
  final String title;
  final String gameType; // 'word', 'puzzle', 'fruit'
  final double entryFee;
  final double prizePool;

  const GameLeaderboardScreen({
    Key? key,
    required this.contestId,
    required this.title,
    required this.gameType,
    required this.entryFee,
    required this.prizePool,
  }) : super(key: key);

  @override
  State<GameLeaderboardScreen> createState() => _GameLeaderboardScreenState();
}

class _GameLeaderboardScreenState extends State<GameLeaderboardScreen> with SingleTickerProviderStateMixin {
  late final ApiClient _apiClient;
  List<GameLeaderboardItem> _standings = [];
  bool _isLoading = true;
  String? _error;
  int? _myUserId;

  WebSocketChannel? _wsChannel;
  StreamSubscription? _wsSubscription;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _apiClient = getIt<ApiClient>();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _loadUserProfile();
    _fetchStandings();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _disconnectWebSocket();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = await getIt<SecureStorageService>().getUser();
      if (user != null) {
        setState(() {
          _myUserId = user.id;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStandings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      String endpoint = '';
      if (widget.gameType == 'word') {
        endpoint = ApiConstants.wordLeaderboard(widget.contestId);
      } else if (widget.gameType == 'puzzle') {
        endpoint = ApiConstants.puzzleLeaderboard(widget.contestId);
      } else if (widget.gameType == 'fruit') {
        endpoint = ApiConstants.fruitLeaderboard(widget.contestId);
      }

      final response = await _apiClient.get(endpoint);
      final list = response.data as List;
      
      setState(() {
        _standings = list
            .map((json) => GameLeaderboardItem.fromJson(json as Map<String, dynamic>, widget.gameType))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _connectWebSocket() {
    _disconnectWebSocket();

    try {
      String wsUrl = '';
      if (widget.gameType == 'word') {
        wsUrl = ApiConstants.wordWs(widget.contestId);
      } else if (widget.gameType == 'puzzle') {
        wsUrl = ApiConstants.puzzleWs(widget.contestId);
      } else if (widget.gameType == 'fruit') {
        wsUrl = ApiConstants.fruitWs(widget.contestId);
      }

      _wsChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _wsSubscription = _wsChannel!.stream.listen((event) {
        try {
          final data = jsonDecode(event);
          if (data is Map && data['type'] == 'leaderboard_update') {
            final rawList = data['data'] as List;
            setState(() {
              _standings = rawList
                  .map((json) => GameLeaderboardItem.fromJson(json as Map<String, dynamic>, widget.gameType))
                  .toList();
            });
          }
        } catch (_) {}
      }, onError: (err) {
        print("Live Standings websocket error: $err");
      });
    } catch (_) {}
  }

  void _disconnectWebSocket() {
    _wsSubscription?.cancel();
    _wsChannel?.sink.close();
  }

  Color _getGameAccentColor() {
    if (widget.gameType == 'fruit') return const Color(0xFFFF4500);
    if (widget.gameType == 'word') return const Color(0xFF00E5FF);
    return const Color(0xFF8A2BE2);
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = _getGameAccentColor();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0816),
      appBar: AppBar(
        title: const Text(
          'STANDINGS & LEADERBOARD',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 14,
          ),
        ),
        backgroundColor: const Color(0xFF13102C),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              _fetchStandings();
              _connectWebSocket();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0C0920), Color(0xFF070514)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Header Stats Card
            _buildContestHeaderCard(accentColor),
            
            // Pulsing Live Indicator
            _buildLiveIndicator(accentColor),
            
            const SizedBox(height: 12),
            
            // Standings headers
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RANK & PLAYER',
                    style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                  Text(
                    'SCORE / DETAILS',
                    style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Divider(color: Colors.white12, height: 1),
            ),
            
            // Standings List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: accentColor))
                  : _error != null
                      ? _buildErrorPlaceholder()
                      : _standings.isEmpty
                          ? _buildEmptyPlaceholder()
                          : RefreshIndicator(
                              onRefresh: () async {
                                _fetchStandings();
                                _connectWebSocket();
                              },
                              color: accentColor,
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: _standings.length,
                                itemBuilder: (context, index) {
                                  return _buildPlayerListItem(_standings[index], accentColor);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContestHeaderCard(Color accentColor) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF13102C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 1.0),
      ),
      child: Column(
        children: [
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildHeaderStat('PRIZE POOL', '₹${widget.prizePool.toStringAsFixed(0)}', Colors.cyanAccent),
              _buildHeaderStat('ENTRY FEE', '₹${widget.entryFee.toStringAsFixed(0)}', Colors.greenAccent),
              _buildHeaderStat('GAME TYPE', widget.gameType.toUpperCase(), Colors.amberAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, Color color) {
    return Column(
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
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveIndicator(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.greenAccent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.6),
                      blurRadius: 4.0 + (6.0 * _pulseController.value),
                      spreadRadius: 1.0 + (3.0 * _pulseController.value),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          const Text(
            'LIVE STREAMING STANDINGS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerListItem(GameLeaderboardItem player, Color accentColor) {
    final isMe = player.userId == _myUserId;
    
    // Metallic gradients and medal badges for top 3 ranks
    Color rankColor = Colors.white54;
    IconData? rankIcon;
    bool isTopThree = player.rank >= 1 && player.rank <= 3;
    
    if (player.rank == 1) {
      rankColor = const Color(0xFFFFD700); // Gold
      rankIcon = Icons.emoji_events;
    } else if (player.rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Silver
      rankIcon = Icons.emoji_events;
    } else if (player.rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankIcon = Icons.emoji_events;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isMe ? accentColor.withOpacity(0.08) : const Color(0xFF13102C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? accentColor : Colors.white.withOpacity(0.05),
          width: isMe ? 1.5 : 1.0,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 50,
          alignment: Alignment.centerLeft,
          child: isTopThree
              ? Row(
                  children: [
                    Icon(rankIcon, color: rankColor, size: 18),
                    const SizedBox(width: 2),
                    Text(
                      '${player.rank}',
                      style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                )
              : Text(
                  '#${player.rank}',
                  style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 13),
                ),
        ),
        title: Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isMe ? accentColor : Colors.white,
            fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        subtitle: isMe
            ? const Text(
                'You',
                style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
              )
            : player.prizeAmount != null && player.prizeAmount! > 0
                ? Text(
                    'Won ₹${player.prizeAmount!.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 9),
                  )
                : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player.score} pts',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              if (player.completionTime != null) ...[
                const SizedBox(height: 2),
                Text(
                  _formatTime(player.completionTime!),
                  style: const TextStyle(color: Colors.white38, fontSize: 8, fontFamily: 'monospace'),
                ),
              ] else if (player.maxCombo != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${player.maxCombo}x Combo',
                  style: const TextStyle(color: Colors.white38, fontSize: 8),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(double sec) {
    int m = sec ~/ 60;
    int s = (sec % 60).toInt();
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Widget _buildErrorPlaceholder() {
    return Center(
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
              onPressed: () {
                _fetchStandings();
                _connectWebSocket();
              },
              style: ElevatedButton.styleFrom(backgroundColor: _getGameAccentColor()),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.emoji_events_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 12),
            Text(
              'No play standings recorded yet.\nBe the first to complete the challenge!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
