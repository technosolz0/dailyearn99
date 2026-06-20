import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';

class WordPrizeRule {
  int minRank;
  int maxRank;
  double prize;

  WordPrizeRule({
    required this.minRank,
    required this.maxRank,
    required this.prize,
  });

  factory WordPrizeRule.fromJson(Map<String, dynamic> json) {
    return WordPrizeRule(
      minRank: json['min_rank'] ?? 1,
      maxRank: json['max_rank'] ?? 1,
      prize: (json['prize'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'min_rank': minRank,
        'max_rank': maxRank,
        'prize': prize,
      };
}

class WordContest {
  final int id;
  final String title;
  final double entryFee;
  final int totalSlots;
  final int joinedSlots;
  final double prizePool;
  final String difficulty;
  final int durationSeconds;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final List<WordPrizeRule> prizeRules;

  WordContest({
    required this.id,
    required this.title,
    required this.entryFee,
    required this.totalSlots,
    required this.joinedSlots,
    required this.prizePool,
    required this.difficulty,
    required this.durationSeconds,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.prizeRules,
  });

  factory WordContest.fromJson(Map<String, dynamic> json) {
    List<WordPrizeRule> rules = [];
    final rawRules = json['prize_rules'];
    if (rawRules != null) {
      if (rawRules is List) {
        rules = rawRules.map((x) => WordPrizeRule.fromJson(x)).toList();
      }
    }
    return WordContest(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Word Contest',
      entryFee: (json['entry_fee'] ?? 0).toDouble(),
      totalSlots: json['total_slots'] ?? 0,
      joinedSlots: json['joined_slots'] ?? 0,
      prizePool: (json['prize_pool'] ?? 0).toDouble(),
      difficulty: json['difficulty'] ?? 'EASY',
      durationSeconds: json['duration_seconds'] ?? 120,
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      status: json['status'] ?? 'UPCOMING',
      prizeRules: rules,
    );
  }
}

class WordQuestion {
  int? id;
  String gameType;
  String difficulty;
  String puzzleData;
  String clues;
  String correctAnswer;
  int pointsReward;

  WordQuestion({
    this.id,
    required this.gameType,
    required this.difficulty,
    required this.puzzleData,
    required this.clues,
    required this.correctAnswer,
    required this.pointsReward,
  });

  factory WordQuestion.fromJson(Map<String, dynamic> json) {
    dynamic pData = json['puzzle_data'];
    String pDataStr = '';
    if (pData != null) {
      if (pData is Map || pData is List) {
        pDataStr = jsonEncode(pData);
      } else {
        pDataStr = pData.toString();
      }
    }

    dynamic hint = json['clues'];
    String hintStr = '';
    if (hint != null) {
      if (hint is Map || hint is List) {
        hintStr = jsonEncode(hint);
      } else {
        hintStr = hint.toString();
      }
    }

    return WordQuestion(
      id: json['id'],
      gameType: json['game_type'] ?? 'UNSCRAMBLE',
      difficulty: json['difficulty'] ?? 'EASY',
      puzzleData: pDataStr,
      clues: hintStr,
      correctAnswer: json['correct_answer'] ?? '',
      pointsReward: json['points_reward'] ?? 100,
    );
  }

  Map<String, dynamic> toJson() {
    dynamic parsedPuzzle;
    try {
      parsedPuzzle = jsonDecode(puzzleData);
    } catch (_) {
      parsedPuzzle = puzzleData;
    }
    
    dynamic parsedClues;
    try {
      if (clues.startsWith('{') || clues.startsWith('[')) {
        parsedClues = jsonDecode(clues);
      } else {
        parsedClues = clues;
      }
    } catch (_) {
      parsedClues = clues;
    }

    return {
      'game_type': gameType,
      'difficulty': difficulty,
      'puzzle_data': parsedPuzzle,
      'clues': parsedClues,
      'correct_answer': correctAnswer,
      'points_reward': pointsReward,
    };
  }
}

class WordManagerView extends StatefulWidget {
  const WordManagerView({super.key});

  @override
  State<WordManagerView> createState() => _WordManagerViewState();
}

class _WordManagerViewState extends State<WordManagerView> with SingleTickerProviderStateMixin {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  late TabController _tabController;

  bool _isLoading = false;
  bool _isSavingQuestions = false;
  String? _error;

  bool _maintenanceVal = false;
  List<WordContest> _contests = [];

  // Vocabulary Editor state
  WordContest? _selectedContest;
  List<WordQuestion> _editedQuestions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final maintenanceRes = await _apiClient.dio.get('/admin/word-puzzle/maintenance');
      final contestsRes = await _apiClient.dio.get('/word-game/contests');

      final contestsList = (contestsRes.data as List).map((x) => WordContest.fromJson(x)).toList();

      setState(() {
        _maintenanceVal = maintenanceRes.data['maintenance_mode'] as bool? ?? false;
        _contests = contestsList;
        _isLoading = false;

        if (contestsList.isNotEmpty && _selectedContest == null) {
          _selectContestForQuestions(contestsList.first);
        }
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.response?.data['detail'] ?? e.message ?? 'Failed to load Word Guessing tournaments';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _selectContestForQuestions(WordContest c) async {
    setState(() {
      _selectedContest = c;
      _editedQuestions = [];
    });

    try {
      final response = await _apiClient.dio.get('/admin/word-puzzle/contests/${c.id}/questions');
      final questions = (response.data as List).map((x) => WordQuestion.fromJson(x)).toList();
      
      setState(() {
        _editedQuestions = questions;
        if (_editedQuestions.isEmpty) {
          _addWordQuestion();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load questions for contest: ${e.toString()}'), backgroundColor: AdminTheme.error),
      );
    }
  }

  Future<void> _toggleMaintenance(bool val) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final res = await _apiClient.dio.post('/admin/word-puzzle/maintenance', queryParameters: {'enabled': val});
      setState(() {
        _maintenanceVal = res.data['maintenance_mode'] as bool? ?? val;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_maintenanceVal ? 'Word puzzle contests are locked.' : 'Word puzzle contests are active.'),
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

  Future<void> _completeContest(WordContest c) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Confirm Completion'),
        content: Text('Are you sure you want to complete "${c.title}" and reward prizes?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(diagContext, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(diagContext, true),
            child: const Text('COMPLETE PAYOUT', style: TextStyle(color: AdminTheme.primary)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _apiClient.dio.post('/admin/word-puzzle/contests/${c.id}/complete');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Word contest payouts distributed!'), backgroundColor: AdminTheme.success),
      );
      await _loadData();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to complete contest'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteContest(WordContest c) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (diagContext) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete "${c.title}"? This deletes matching vocabularies & attempts logs!'),
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
      await _apiClient.dio.delete('/admin/word-puzzle/contests/${c.id}');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Word contest deleted successfully.'), backgroundColor: AdminTheme.success),
      );
      setState(() {
        _selectedContest = null;
      });
      await _loadData();
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to delete contest'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addWordQuestion() {
    setState(() {
      _editedQuestions.add(WordQuestion(
        gameType: 'UNSCRAMBLE',
        difficulty: 'EASY',
        puzzleData: '{\n  "scrambled": "TDAR"\n}',
        clues: 'Target language for Flutter apps.',
        correctAnswer: 'DART',
        pointsReward: 100,
      ));
    });
  }

  void _removeWordQuestion(int index) {
    setState(() {
      _editedQuestions.removeAt(index);
    });
  }

  Future<void> _saveBulkQuestions() async {
    if (_selectedContest == null) return;
    
    // Verify inputs
    for (int i = 0; i < _editedQuestions.length; i++) {
      final q = _editedQuestions[i];
      if (q.correctAnswer.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question #${i + 1} correctAnswer is empty.'), backgroundColor: AdminTheme.error),
        );
        return;
      }
      try {
        jsonDecode(q.puzzleData);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Question #${i + 1} puzzleData is not valid JSON.'), backgroundColor: AdminTheme.error),
        );
        return;
      }
    }

    setState(() {
      _isSavingQuestions = true;
    });

    try {
      final payload = _editedQuestions.map((q) => q.toJson()).toList();
      await _apiClient.dio.post(
        '/admin/word-puzzle/questions/bulk/${_selectedContest!.id}',
        data: payload,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Word vocabularies saved successfully!'), backgroundColor: AdminTheme.success),
      );
      await _selectContestForQuestions(_selectedContest!);
      setState(() {
        _isSavingQuestions = false;
      });
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to save bulk vocabulary'), backgroundColor: AdminTheme.error),
      );
      setState(() {
        _isSavingQuestions = false;
      });
    }
  }

  void _showLaunchModal() {
    showDialog(
      context: context,
      builder: (modalContext) => LaunchWordContestDialog(
        onSubmit: (payload) async {
          setState(() {
            _isLoading = true;
          });
          try {
            await _apiClient.dio.post('/admin/word-puzzle/contests', data: payload);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Word guessing contest launched successfully!'), backgroundColor: AdminTheme.success),
            );
            await _loadData();
          } on DioException catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.response?.data['detail'] ?? 'Failed to launch word contest'), backgroundColor: AdminTheme.error),
            );
            setState(() {
              _isLoading = false;
            });
          }
        },
      ),
    );
  }

  Widget _buildLobbiesTab(NumberFormat currencyFormatter) {
    if (_contests.isEmpty) {
      return const Center(child: Text('No word contests active or defined yet.', style: TextStyle(color: AdminTheme.textMuted)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contests.length,
      itemBuilder: (context, index) {
        final c = _contests[index];
        final startStr = DateFormat.yMMMd().add_jm().format(c.startTime);
        final progress = c.totalSlots > 0 ? c.joinedSlots / c.totalSlots : 0.0;
        
        Color statusColor = AdminTheme.warning;
        if (c.status == 'ACTIVE') statusColor = AdminTheme.success;
        if (c.status == 'COMPLETED') statusColor = AdminTheme.info;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        c.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        c.status,
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Entry Fee', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                        Text(currencyFormatter.format(c.entryFee), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.primary)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Prize Pool', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                        Text(currencyFormatter.format(c.prizePool), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AdminTheme.success)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Slots Filled', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                        Text('${c.joinedSlots} / ${c.totalSlots}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AdminTheme.borderColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(AdminTheme.primary),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.gamepad_outlined, size: 14, color: AdminTheme.textMuted),
                    const SizedBox(width: 4),
                    Text('Difficulty: ${c.difficulty} | Duration: ${c.durationSeconds}s', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AdminTheme.textMuted),
                    const SizedBox(width: 4),
                    Text('Starts: $startStr', style: const TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                  ],
                ),
                const Divider(color: AdminTheme.borderColor, height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: AdminTheme.error),
                      onPressed: () => _deleteContest(c),
                    ),
                    const Spacer(),
                    if (c.status != 'COMPLETED') ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          backgroundColor: AdminTheme.success,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _completeContest(c),
                        child: const Text('Complete & Pay', style: TextStyle(fontSize: 12)),
                      ),
                    ] else ...[
                      const Text('Payout Completed', style: TextStyle(fontSize: 12, color: AdminTheme.textMuted, fontStyle: FontStyle.italic)),
                    ]
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVocabTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Dropdown selection card
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<WordContest>(
              value: _selectedContest,
              decoration: const InputDecoration(labelText: 'Select Word Contest Lobby'),
              items: _contests.map((c) {
                return DropdownMenuItem<WordContest>(value: c, child: Text('${c.title} (ID: ${c.id})'));
              }).toList(),
              onChanged: (val) {
                if (val != null) _selectContestForQuestions(val);
              },
            ),
          ),
        ),

        if (_selectedContest != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Questions list (${_editedQuestions.length})',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AdminTheme.textMain),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.secondary,
                    foregroundColor: AdminTheme.textMain,
                  ),
                  onPressed: _addWordQuestion,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('ADD WORD'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _editedQuestions.length,
              itemBuilder: (context, idx) {
                final q = _editedQuestions[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: AdminTheme.primary.withOpacity(0.1),
                              radius: 12,
                              child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: AdminTheme.primary, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 8),
                            const Text('Word Config', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: AdminTheme.error),
                              onPressed: () => _removeWordQuestion(idx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: q.gameType,
                                decoration: const InputDecoration(labelText: 'Game Type'),
                                items: const [
                                  DropdownMenuItem(value: 'UNSCRAMBLE', child: Text('UNSCRAMBLE')),
                                  DropdownMenuItem(value: 'MISSING_LETTERS', child: Text('MISSING_LETTERS')),
                                  DropdownMenuItem(value: 'WORD_SEARCH', child: Text('WORD_SEARCH')),
                                  DropdownMenuItem(value: 'CROSSWORD', child: Text('CROSSWORD')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      q.gameType = val;
                                      // Update puzzle data helper text based on template
                                      if (val == 'UNSCRAMBLE') {
                                        q.puzzleData = '{\n  "scrambled": "TDAR"\n}';
                                      } else if (val == 'MISSING_LETTERS') {
                                        q.puzzleData = '{\n  "pattern": "D_R_"\n}';
                                      } else if (val == 'WORD_SEARCH') {
                                        q.puzzleData = '{\n  "grid": [\n    ["B","L","O","C"],\n    ["X","Y","Z","A"]\n  ]\n}';
                                      } else if (val == 'CROSSWORD') {
                                        q.puzzleData = '{\n  "grid": [["D","A","R","T"]],\n  "row": 0,\n  "col": 0,\n  "direction": "horizontal"\n}';
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: q.difficulty,
                                decoration: const InputDecoration(labelText: 'Difficulty'),
                                items: const [
                                  DropdownMenuItem(value: 'EASY', child: Text('EASY')),
                                  DropdownMenuItem(value: 'MEDIUM', child: Text('MEDIUM')),
                                  DropdownMenuItem(value: 'HARD', child: Text('HARD')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      q.difficulty = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                initialValue: q.correctAnswer,
                                decoration: const InputDecoration(labelText: 'Correct Word Answer'),
                                onChanged: (val) => q.correctAnswer = val.toUpperCase(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                initialValue: q.pointsReward.toString(),
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Points Coins Reward'),
                                onChanged: (val) => q.pointsReward = int.tryParse(val) ?? 100,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: q.clues,
                          decoration: const InputDecoration(labelText: 'Clue Hint / Description'),
                          onChanged: (val) => q.clues = val,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: q.puzzleData,
                          maxLines: 4,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.green),
                          decoration: const InputDecoration(
                            labelText: 'Puzzle Layout Data (JSON)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (val) => q.puzzleData = val,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isSavingQuestions
                ? const Center(child: CircularProgressIndicator(color: AdminTheme.primary))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primary,
                      foregroundColor: AdminTheme.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saveBulkQuestions,
                    child: const Text('SAVE ALL VOCABULARIES', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
          ),
        ] else ...[
          const Expanded(
            child: Center(
              child: Text('Create a Word contest or select one from the dropdown to load questions.', style: TextStyle(color: AdminTheme.textMuted)),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

    if (_isLoading && _contests.isEmpty) {
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
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
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
              Tab(icon: Icon(Icons.list_alt), text: 'Lobbies'),
              Tab(icon: Icon(Icons.menu_book), text: 'Vocabulary questions'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          Scaffold(
            floatingActionButton: FloatingActionButton(
              backgroundColor: AdminTheme.primary,
              foregroundColor: AdminTheme.background,
              onPressed: _showLaunchModal,
              child: const Icon(Icons.add),
            ),
            body: RefreshIndicator(
              onRefresh: _loadData,
              child: _buildLobbiesTab(currencyFormatter),
            ),
          ),
          RefreshIndicator(
            onRefresh: () async {
              if (_selectedContest != null) {
                await _selectContestForQuestions(_selectedContest!);
              }
            },
            child: _buildVocabTab(),
          ),
        ],
      ),
    );
  }
}

class LaunchWordContestDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;

  const LaunchWordContestDialog({super.key, required this.onSubmit});

  @override
  State<LaunchWordContestDialog> createState() => _LaunchWordContestDialogState();
}

class _LaunchWordContestDialogState extends State<LaunchWordContestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _feeController = TextEditingController(text: '15');
  final _slotsController = TextEditingController(text: '100');
  final _poolController = TextEditingController(text: '1100');
  final _durationController = TextEditingController(text: '120');
  String _difficulty = 'EASY';

  DateTime _startDate = DateTime.now().add(const Duration(minutes: 10));
  TimeOfDay _startTime = TimeOfDay.now();

  final List<WordPrizeRule> _prizeRules = [];

  void _addPrizeRule() {
    int nextMin = 1;
    if (_prizeRules.isNotEmpty) {
      nextMin = _prizeRules.last.maxRank + 1;
    }
    setState(() {
      _prizeRules.add(WordPrizeRule(minRank: nextMin, maxRank: nextMin, prize: 50.0));
    });
  }

  void _removePrizeRule(int index) {
    setState(() {
      _prizeRules.removeAt(index);
    });
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (time == null) return;

    setState(() {
      _startDate = date;
      _startTime = time;
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final start = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final payload = {
        'title': _titleController.text.trim(),
        'entry_fee': double.parse(_feeController.text),
        'total_slots': int.parse(_slotsController.text),
        'prize_pool': double.parse(_poolController.text),
        'difficulty': _difficulty,
        'duration_seconds': int.parse(_durationController.text),
        'start_time': start.toUtc().toIso8601String(),
        'end_time': start.add(const Duration(hours: 24)).toUtc().toIso8601String(), // Require end time for Word
        'prize_rules': _prizeRules.map((r) => r.toJson()).toList(),
      };

      widget.onSubmit(payload);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final startFormat = '${DateFormat.yMMMd().format(_startDate)} ${_startTime.format(context)}';

    return AlertDialog(
      title: const Text('Launch Word Contest'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Contest Title'),
                validator: (val) => val == null || val.isEmpty ? 'Title required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _difficulty,
                decoration: const InputDecoration(labelText: 'Contest Difficulty'),
                items: const [
                  DropdownMenuItem(value: 'EASY', child: Text('EASY')),
                  DropdownMenuItem(value: 'MEDIUM', child: Text('MEDIUM')),
                  DropdownMenuItem(value: 'HARD', child: Text('HARD')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _difficulty = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _feeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Entry Fee (INR)'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _poolController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prize Pool'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _slotsController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Total Slots'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Duration (Sec)'),
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Start Date & Time', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted)),
                subtitle: Text(startFormat, style: const TextStyle(fontWeight: FontWeight.bold, color: AdminTheme.textMain)),
                trailing: const Icon(Icons.calendar_today, color: AdminTheme.primary),
                onTap: _pickDateTime,
              ),
              const Divider(color: AdminTheme.borderColor, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Rank Prize Rules', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(onPressed: _addPrizeRule, child: const Text('+ ADD RULE')),
                ],
              ),
              const SizedBox(height: 8),
              if (_prizeRules.isEmpty)
                const Text('Default distribution will apply if no rules are added.', style: TextStyle(fontSize: 11, color: AdminTheme.textMuted, fontStyle: FontStyle.italic))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _prizeRules.length,
                  itemBuilder: (context, idx) {
                    final rule = _prizeRules[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: rule.minRank.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Min Rank'),
                              onChanged: (val) => rule.minRank = int.tryParse(val) ?? 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text('to'),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextFormField(
                              initialValue: rule.maxRank.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Max Rank'),
                              onChanged: (val) => rule.maxRank = int.tryParse(val) ?? 1,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextFormField(
                              initialValue: rule.prize.toString(),
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Prize (₹)'),
                              onChanged: (val) => rule.prize = double.tryParse(val) ?? 0.0,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: AdminTheme.error, size: 18),
                            onPressed: () => _removePrizeRule(idx),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
        TextButton(onPressed: _submit, child: const Text('LAUNCH CONTEST', style: TextStyle(color: AdminTheme.primary))),
      ],
    );
  }
}
