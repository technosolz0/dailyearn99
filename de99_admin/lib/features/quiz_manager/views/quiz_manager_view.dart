import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:de99_admin/core/network/api_client.dart';
import 'package:de99_admin/core/theme/admin_theme.dart';

class QuizQuestion {
  String text;
  List<String> options;
  int correctAnswerIndex;

  QuizQuestion({
    required this.text,
    required this.options,
    required this.correctAnswerIndex,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final opts = List<String>.from(json['options'] ?? ['', '', '', '']);
    while (opts.length < 4) {
      opts.add('');
    }
    return QuizQuestion(
      text: json['text'] ?? '',
      options: opts,
      correctAnswerIndex: json['correct_answer_index'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'text': text,
    'options': options,
    'correct_answer_index': correctAnswerIndex,
  };
}

class QuizContestBrief {
  final int id;
  final String title;
  final List<QuizQuestion> questions;

  QuizContestBrief({
    required this.id,
    required this.title,
    required this.questions,
  });

  factory QuizContestBrief.fromJson(Map<String, dynamic> json) {
    List<QuizQuestion> qList = [];
    final rawQs = json['questions'];
    if (rawQs != null) {
      try {
        if (rawQs is String) {
          // Sometimes stored as JSON-encoded string
          final decoded = List<dynamic>.from(
            rawQs.isEmpty
                ? []
                : (rawQs.startsWith('[') ? (rawQs.split(',')) : []),
          );
          // Better to handle if backend parsed it as array or string
        } else if (rawQs is List) {
          qList = rawQs.map((x) => QuizQuestion.fromJson(x)).toList();
        }
      } catch (e) {
        // Fallback
      }
    }
    return QuizContestBrief(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      questions: qList,
    );
  }
}

class QuizManagerView extends StatefulWidget {
  const QuizManagerView({super.key});

  @override
  State<QuizManagerView> createState() => _QuizManagerViewState();
}

class _QuizManagerViewState extends State<QuizManagerView> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  bool _maintenanceVal = false;
  List<QuizContestBrief> _contests = [];
  QuizContestBrief? _selectedContest;
  List<QuizQuestion> _editedQuestions = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final maintenanceRes = await _apiClient.dio.get(
        '/admin/quiz/maintenance',
      );
      final contestsRes = await _apiClient.dio.get('/contests');

      final maintenanceMode =
          maintenanceRes.data['maintenance_mode'] as bool? ?? false;

      // Parse contests questions properly. In contests endpoint, it might return a string or list for questions
      final contests = (contestsRes.data as List).map((json) {
        List<QuizQuestion> questions = [];
        final rawQs = json['questions'];
        if (rawQs is String && rawQs.isNotEmpty) {
          try {
            // Decodes stringified questions JSON

            final decoded = jsonDecode(rawQs) as List;
            questions = decoded.map((x) => QuizQuestion.fromJson(x)).toList();
          } catch (_) {}
        } else if (rawQs is List) {
          questions = rawQs.map((x) => QuizQuestion.fromJson(x)).toList();
        }
        return QuizContestBrief(
          id: json['id'] ?? 0,
          title: json['title'] ?? 'Contest #${json['id']}',
          questions: questions,
        );
      }).toList();

      setState(() {
        _maintenanceVal = maintenanceMode;
        _contests = contests;
        _isLoading = false;

        if (contests.isNotEmpty) {
          _selectContest(contests.first);
        }
      });
    } on DioException catch (e) {
      setState(() {
        _isLoading = false;
        _error =
            e.response?.data['detail'] ??
            e.message ??
            'Failed to load Quiz Manager';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _selectContest(QuizContestBrief contest) {
    setState(() {
      _selectedContest = contest;
      // Perform deep copy of questions to avoid direct mutations
      _editedQuestions = contest.questions
          .map(
            (q) => QuizQuestion(
              text: q.text,
              options: List<String>.from(q.options),
              correctAnswerIndex: q.correctAnswerIndex,
            ),
          )
          .toList();

      if (_editedQuestions.isEmpty) {
        _addQuestion();
      }
    });
  }

  Future<void> _toggleMaintenance(bool val) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final res = await _apiClient.dio.post(
        '/admin/quiz/maintenance',
        queryParameters: {'enabled': val},
      );
      setState(() {
        _maintenanceVal = res.data['maintenance_mode'] as bool? ?? val;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _maintenanceVal
                ? 'Quiz contests are locked!'
                : 'Quiz contests are active.',
          ),
          backgroundColor: _maintenanceVal
              ? AdminTheme.error
              : AdminTheme.success,
        ),
      );
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data['detail'] ?? 'Failed to toggle maintenance mode',
          ),
          backgroundColor: AdminTheme.error,
        ),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addQuestion() {
    setState(() {
      _editedQuestions.add(
        QuizQuestion(
          text: '',
          options: ['', '', '', ''],
          correctAnswerIndex: 0,
        ),
      );
    });
  }

  void _removeQuestion(int index) {
    setState(() {
      _editedQuestions.removeAt(index);
    });
  }

  Future<void> _saveQuestions() async {
    if (_selectedContest == null) return;

    // Verify inputs
    for (int i = 0; i < _editedQuestions.length; i++) {
      final q = _editedQuestions[i];
      if (q.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question #${i + 1} cannot have empty text.'),
            backgroundColor: AdminTheme.error,
          ),
        );
        return;
      }
      for (int o = 0; o < 4; o++) {
        if (q.options[o].trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Question #${i + 1} option ${String.fromCharCode(65 + o)} is empty.',
              ),
              backgroundColor: AdminTheme.error,
            ),
          );
          return;
        }
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final dataList = _editedQuestions.map((q) => q.toJson()).toList();
      await _apiClient.dio.post(
        '/admin/contests/${_selectedContest!.id}/questions',
        data: dataList,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Quiz questions updated successfully!'),
          backgroundColor: AdminTheme.success,
        ),
      );
      // Reload contests to update memory
      await _loadData();
      setState(() {
        _isSaving = false;
      });
    } on DioException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data['detail'] ?? 'Failed to save questions',
          ),
          backgroundColor: AdminTheme.error,
        ),
      );
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _contests.isEmpty) {
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
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Maintenance Card
              Card(
                child: SwitchListTile(
                  activeColor: AdminTheme.error,
                  title: const Text(
                    'Quiz Maintenance Lockout',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Instantly hide all quiz contests from the client application',
                  ),
                  value: _maintenanceVal,
                  onChanged: _toggleMaintenance,
                ),
              ),
              const SizedBox(height: 16),

              // Contest Selector
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: DropdownButtonFormField<QuizContestBrief>(
                    value: _selectedContest,
                    decoration: const InputDecoration(
                      labelText: 'Select Contest Lobby',
                      prefixIcon: Icon(Icons.sports_esports),
                    ),
                    items: _contests.map((c) {
                      return DropdownMenuItem<QuizContestBrief>(
                        value: c,
                        child: Text('${c.title} (ID: ${c.id})'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        _selectContest(val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              if (_selectedContest != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Questions list (${_editedQuestions.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AdminTheme.textMain,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.secondary,
                        foregroundColor: AdminTheme.textMain,
                      ),
                      onPressed: _addQuestion,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('ADD QUESTION'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Question Cards
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _editedQuestions.length,
                  itemBuilder: (context, index) {
                    final q = _editedQuestions[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AdminTheme.primary
                                      .withOpacity(0.1),
                                  radius: 14,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AdminTheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Question Details',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AdminTheme.error,
                                  ),
                                  onPressed: () => _removeQuestion(index),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              initialValue: q.text,
                              decoration: const InputDecoration(
                                labelText: 'Question Text',
                                hintText: 'Enter question here...',
                              ),
                              onChanged: (val) => q.text = val,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Answer Choices',
                              style: TextStyle(
                                fontSize: 12,
                                color: AdminTheme.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GridPaper(
                              color: Colors.transparent,
                              child: GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 8,
                                childAspectRatio: 3,
                                children: List.generate(4, (optIdx) {
                                  final optionChar = String.fromCharCode(
                                    65 + optIdx,
                                  );
                                  return TextFormField(
                                    initialValue: q.options[optIdx],
                                    decoration: InputDecoration(
                                      labelText: 'Option $optionChar',
                                    ),
                                    onChanged: (val) => q.options[optIdx] = val,
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Text(
                                  'Correct Answer: ',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AdminTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<int>(
                                  value: q.correctAnswerIndex,
                                  dropdownColor: AdminTheme.surfaceDark,
                                  items: List.generate(4, (optIdx) {
                                    return DropdownMenuItem<int>(
                                      value: optIdx,
                                      child: Text(
                                        'Option ${String.fromCharCode(65 + optIdx)}',
                                      ),
                                    );
                                  }),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        q.correctAnswerIndex = val;
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),
                if (_isSaving)
                  const Center(
                    child: CircularProgressIndicator(color: AdminTheme.primary),
                  )
                else
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.primary,
                      foregroundColor: AdminTheme.background,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _saveQuestions,
                    child: const Text(
                      'SAVE CONTEST QUESTIONS',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
