import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:target99/core/theme/app_theme.dart';
import 'package:target99/core/models/contest_model.dart';
import 'package:target99/features/app_bloc.dart';

class LeaderboardScreen extends StatefulWidget {
  final ContestModel contest;
  const LeaderboardScreen({super.key, required this.contest});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(screenName: 'LeaderboardScreen');
    // Subscribe to live websocket updates for this contest
    context.read<AppBloc>().add(ConnectLeaderboardEvent(widget.contest.id));
  }

  @override
  void dispose() {
    // Unsubscribe from websocket channel
    context.read<AppBloc>().add(DisconnectLeaderboardEvent());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Leaderboard'),
        backgroundColor: AppTheme.darkBg,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.accentCyan),
            onPressed: () {
              context.read<AppBloc>().add(ConnectLeaderboardEvent(widget.contest.id));
            },
          )
        ],
      ),
      body: BlocBuilder<AppBloc, AppState>(
        builder: (context, state) {
          if (state.isLeaderboardLoading && state.activeLeaderboard.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            );
          }

          final list = state.activeLeaderboard;
          final user = state.currentUser;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.darkBg, Color(0xFF0F1426)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Contest info bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Card(
                    color: AppTheme.cardBg.withOpacity(0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            widget.contest.title,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _infoSub('Pool', '₹${widget.contest.prizePool.toInt()}', AppTheme.accentEmerald),
                              _infoSub('Entry', '₹${widget.contest.entryFee.toInt()}', AppTheme.accentCyan),
                              _infoSub('Status', widget.contest.status, AppTheme.accentAmber),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),

                // Live status connection glowing indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentEmerald,
                          boxShadow: [
                            BoxShadow(color: AppTheme.accentEmerald, blurRadius: 8, spreadRadius: 1),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'WS CONNECTED: STREAMING REAL-TIME RANKS',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: AppTheme.accentEmerald),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Table headers
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('RANK / PLAYER', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                      Text('SCORE', style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Divider(color: AppTheme.borderCol, height: 1),
                ),

                // Leaderboard List
                Expanded(
                  child: list.isEmpty
                      ? const Center(
                          child: Text(
                            'Waiting for scores...\nNo play data submitted yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textMuted, fontStyle: FontStyle.italic),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: list.length,
                          itemBuilder: (context, index) {
                            final player = list[index];
                            final isMe = player.userId == user?.id;
                            
                            // Styling for ranks 1, 2, 3
                            Color rankColor = AppTheme.textMuted;
                            String rankText = player.rank.toString();
                            IconData? rankIcon;

                            if (player.rank == 1) {
                              rankColor = AppTheme.accentAmber;
                              rankIcon = Icons.emoji_events;
                            } else if (player.rank == 2) {
                              rankColor = const Color(0xFFC0C0C0); // Silver
                              rankIcon = Icons.emoji_events;
                            } else if (player.rank == 3) {
                              rankColor = const Color(0xFFCD7F32); // Bronze
                              rankIcon = Icons.emoji_events;
                            }

                            return Card(
                              color: isMe ? AppTheme.accentCyan.withOpacity(0.08) : AppTheme.cardBg,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isMe ? AppTheme.accentCyan : AppTheme.borderCol,
                                  width: isMe ? 1.5 : 1,
                                ),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 44,
                                  alignment: Alignment.center,
                                  child: rankIcon != null
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(rankIcon, color: rankColor, size: 18),
                                            const SizedBox(width: 2),
                                            Text(rankText, style: TextStyle(color: rankColor, fontWeight: FontWeight.bold)),
                                          ],
                                        )
                                      : Text(
                                          rankText,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                ),
                                title: Text(
                                  player.name,
                                  style: TextStyle(
                                    fontWeight: isMe ? FontWeight.bold : FontWeight.w500,
                                    color: isMe ? AppTheme.accentCyan : Colors.white,
                                  ),
                                ),
                                subtitle: isMe
                                    ? const Text('You', style: TextStyle(color: AppTheme.accentCyan, fontSize: 10))
                                    : null,
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${player.score} pts',
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoSub(String label, String val, Color color) {
    return Column(
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 8, color: AppTheme.textMuted, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(val, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
