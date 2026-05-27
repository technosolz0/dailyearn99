import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:target99/core/theme/app_theme.dart';
import 'package:target99/core/models/contest_model.dart';
import 'package:target99/features/app_bloc.dart';
import 'package:target99/features/contest/leaderboard_screen.dart';
import 'package:target99/core/network/api_client.dart';
import 'package:target99/core/utils/dependency_injection.dart';

class QuizQuestion {
  final String text;
  final List<String> options;
  final int correctAnswerIndex;

  QuizQuestion(this.text, this.options, this.correctAnswerIndex);
}

class QuizScreen extends StatefulWidget {
  final ContestModel contest;
  final String language;
  const QuizScreen({super.key, required this.contest, this.language = 'en'});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<QuizQuestion> _questions = [];
  bool _isLoading = true;
  String? _errorMessage;

  int _currentQuestionIndex = 0;
  int _selectedAnswerIndex = -1;
  int _score = 0;
  int _secondsRemaining = 10;
  Timer? _timer;
  bool _isQuizOver = false;
  final List<int> _selectedAnswers = [];

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(screenName: 'QuizScreen');
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final response = await getIt<ApiClient>().get(
        '/contests/${widget.contest.id}/questions',
        queryParameters: {'lang': widget.language},
      );
      final data = response.data as List;

      if (mounted) {
        setState(() {
          _questions = data.map((json) {
            return QuizQuestion(
              json['text'] as String,
              List<String>.from(json['options'] as List),
              json['correct_answer_index'] as int,
            );
          }).toList();
          _isLoading = false;
        });
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  void _startTimer() {
    _secondsRemaining = 10;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
          } else {
            _nextQuestion();
          }
        });
      }
    });
  }

  void _nextQuestion() {
    // Record selected answer
    _selectedAnswers.add(_selectedAnswerIndex);

    // Record score
    if (_selectedAnswerIndex ==
        _questions[_currentQuestionIndex].correctAnswerIndex) {
      _score += 20; // 20 points per question
    }

    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = -1;
      });
      _startTimer();
    } else {
      _finishQuiz();
    }
  }

  void _finishQuiz() {
    _timer?.cancel();
    setState(() {
      _isQuizOver = true;
    });

    // Submit score & answers to FastAPI Backend
    context.read<AppBloc>().add(
      SubmitScoreEvent(widget.contest.id, _score, answers: _selectedAnswers),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contest.title),
        backgroundColor: AppTheme.darkBg,
        automaticallyImplyLeading: !_isQuizOver,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.darkBg, Color(0xFF0F1426)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.accentCyan),
                )
              : _errorMessage != null
              ? _buildErrorView(context)
              : _isQuizOver
              ? _buildResultView(context)
              : _buildQuizView(_questions[_currentQuestionIndex]),
        ),
      ),
    );
  }

  Widget _buildErrorView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 72,
          color: AppTheme.accentRed,
        ),
        const SizedBox(height: 16),
        const Text(
          'Failed to Load Quiz',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ??
              'An error occurred while preparing your quiz session.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('GO BACK TO LOBBY'),
        ),
      ],
    );
  }

  Widget _buildQuizView(QuizQuestion question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentQuestionIndex + 1}/${_questions.length}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textMuted,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _secondsRemaining <= 4
                    ? AppTheme.accentRed.withOpacity(0.1)
                    : AppTheme.accentCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _secondsRemaining <= 4
                      ? AppTheme.accentRed.withOpacity(0.3)
                      : AppTheme.accentCyan.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: _secondsRemaining <= 4
                        ? AppTheme.accentRed
                        : AppTheme.accentCyan,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_secondsRemaining}s',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _secondsRemaining <= 4
                          ? AppTheme.accentRed
                          : AppTheme.accentCyan,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LinearProgressIndicator(
          value: (_currentQuestionIndex + 1) / _questions.length,
          backgroundColor: Colors.white.withOpacity(0.05),
          valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 32),

        // Question Text Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              question.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Options Grid
        Expanded(
          child: ListView.builder(
            itemCount: question.options.length,
            itemBuilder: (context, index) {
              final optionText = question.options[index];
              final isSelected = _selectedAnswerIndex == index;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedAnswerIndex = index;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentCyan.withOpacity(0.08)
                          : AppTheme.cardBg,
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentCyan
                            : AppTheme.borderCol,
                        width: isSelected ? 1.5 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accentCyan
                                  : AppTheme.textMuted,
                              width: 2,
                            ),
                            color: isSelected
                                ? AppTheme.accentCyan
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.black,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            optionText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? Colors.white
                                  : AppTheme.textMain,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Next Button
        ElevatedButton(
          onPressed: _selectedAnswerIndex == -1 ? null : _nextQuestion,
          child: Text(
            _currentQuestionIndex == _questions.length - 1
                ? 'SUBMIT ANSWERS'
                : 'NEXT QUESTION',
          ),
        ),
      ],
    );
  }

  Widget _buildResultView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.workspace_premium,
          size: 72,
          color: AppTheme.accentAmber,
        ),
        const SizedBox(height: 16),
        const Text(
          'Quiz Completed!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your scores were submitted successfully to the contest engine',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
        ),
        const SizedBox(height: 32),

        // Score summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text(
                  'YOUR SCORE',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_score / ${_questions.length * 20}',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentCyan,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),

        ElevatedButton(
          onPressed: () {
            // Direct user straight to live websocket leaderboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    LeaderboardScreen(contest: widget.contest),
              ),
            );
          },
          child: const Text('VIEW LIVE LEADERBOARD 🏆'),
        ),
      ],
    );
  }
}
