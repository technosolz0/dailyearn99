import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:target99/core/theme/app_theme.dart';
import 'package:target99/core/models/contest_model.dart';
import 'package:target99/features/app_bloc.dart';
import 'package:target99/features/contest/leaderboard_screen.dart';

class QuizQuestion {
  final String text;
  final List<String> options;
  final int correctAnswerIndex;

  QuizQuestion(this.text, this.options, this.correctAnswerIndex);
}

class QuizScreen extends StatefulWidget {
  final ContestModel contest;
  const QuizScreen({super.key, required this.contest});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final List<QuizQuestion> _questions = [
    QuizQuestion('Which country won the ICC Men\'s T20 World Cup in 2024?', ['India', 'South Africa', 'Australia', 'England'], 0),
    QuizQuestion('In computer networking, what does VPN stand for?', ['Virtual Private Network', 'Vector Protocol Node', 'Valued Personal Network', 'Virtual Packet Node'], 0),
    QuizQuestion('Which programming language is predominantly used to write Flutter apps?', ['Swift', 'Dart', 'Kotlin', 'Rust'], 1),
    QuizQuestion('What is the national game of India officially/historically?', ['Cricket', 'Kabaddi', 'Field Hockey', 'Football'], 2),
    QuizQuestion('What is the platform fee target percentage in target99?', ['10-20%', '15-35%', '50-60%', '5%'], 1),
  ];

  int _currentQuestionIndex = 0;
  int _selectedAnswerIndex = -1;
  int _score = 0;
  int _secondsRemaining = 12;
  Timer? _timer;
  bool _isQuizOver = false;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logScreenView(screenName: 'QuizScreen');
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 12;
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
    // Record score
    if (_selectedAnswerIndex == _questions[_currentQuestionIndex].correctAnswerIndex) {
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
    
    // Submit score to FastAPI Backend
    context.read<AppBloc>().add(SubmitScoreEvent(widget.contest.id, _score));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_currentQuestionIndex];
    
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
          child: _isQuizOver ? _buildResultView(context) : _buildQuizView(question),
        ),
      ),
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
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textMuted),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _secondsRemaining <= 4 ? AppTheme.accentRed.withOpacity(0.1) : AppTheme.accentCyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _secondsRemaining <= 4 ? AppTheme.accentRed.withOpacity(0.3) : AppTheme.accentCyan.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: _secondsRemaining <= 4 ? AppTheme.accentRed : AppTheme.accentCyan,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${_secondsRemaining}s',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _secondsRemaining <= 4 ? AppTheme.accentRed : AppTheme.accentCyan,
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 1.4),
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
                      color: isSelected ? AppTheme.accentCyan.withOpacity(0.08) : AppTheme.cardBg,
                      border: Border.all(
                        color: isSelected ? AppTheme.accentCyan : AppTheme.borderCol,
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
                              color: isSelected ? AppTheme.accentCyan : AppTheme.textMuted,
                              width: 2,
                            ),
                            color: isSelected ? AppTheme.accentCyan : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 14, color: Colors.black)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            optionText,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : AppTheme.textMain,
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
          child: Text(_currentQuestionIndex == _questions.length - 1 ? 'SUBMIT ANSWERS' : 'NEXT QUESTION'),
        ),
      ],
    );
  }

  Widget _buildResultView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.workspace_premium,
          size: 72,
          color: AppTheme.accentAmber,
        ),
        const SizedBox(height: 16),
        Text(
          'Quiz Completed!',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
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
                Text(
                  'YOUR SCORE',
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  '$_score / 100',
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppTheme.accentCyan),
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
                builder: (context) => LeaderboardScreen(contest: widget.contest),
              ),
            );
          },
          child: const Text('VIEW LIVE LEADERBOARD 🏆'),
        ),
      ],
    );
  }
}
