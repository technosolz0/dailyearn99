import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dailyearn99/core/theme/app_theme.dart';

class ContestTimerWidget extends StatefulWidget {
  final DateTime startTime;
  final DateTime? endTime;
  final String status;
  final bool isJoined;

  const ContestTimerWidget({
    super.key,
    required this.startTime,
    this.endTime,
    required this.status,
    required this.isJoined,
  });

  @override
  State<ContestTimerWidget> createState() => _ContestTimerWidgetState();
}

class _ContestTimerWidgetState extends State<ContestTimerWidget> {
  Timer? _timer;
  String _timeString = "";
  String _label = "";
  Color _accentColor = AppTheme.textMuted;
  IconData _icon = Icons.timer_outlined;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTime();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ContestTimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateTime();
  }

  void _updateTime() {
    final now = DateTime.now();
    final startLocal = widget.startTime.toLocal();
    final endLocal = widget.endTime?.toLocal();

    String normStatus = widget.status.toUpperCase();

    // Check if time triggers state override
    if (normStatus == "UPCOMING" && now.isAfter(startLocal)) {
      normStatus = "ACTIVE";
    }
    if (normStatus == "ACTIVE" && endLocal != null && now.isAfter(endLocal)) {
      normStatus = "COMPLETED";
    }

    if (normStatus == "UPCOMING") {
      final diff = startLocal.difference(now);
      if (diff.inSeconds <= 0) {
        setState(() {
          _label = "STARTS SOON";
          _timeString = "";
          _accentColor = AppTheme.accentCyan;
          _icon = Icons.play_arrow_outlined;
        });
      } else if (diff.inHours < 24) {
        setState(() {
          _label = widget.isJoined ? "REGISTERED • STARTS IN:" : "STARTS IN:";
          _timeString = _formatDuration(diff);
          _accentColor = AppTheme.accentOrange;
          _icon = Icons.hourglass_top_outlined;
        });
      } else {
        setState(() {
          _label = widget.isJoined ? "REGISTERED • STARTS AT:" : "STARTS AT:";
          _timeString = _formatDateTime(startLocal);
          _accentColor = AppTheme.textMuted;
          _icon = Icons.calendar_today_outlined;
        });
      }
    } else if (normStatus == "ACTIVE") {
      if (endLocal == null) {
        setState(() {
          _label = "LIVE NOW";
          _timeString = "";
          _accentColor = AppTheme.accentEmerald;
          _icon = Icons.play_circle_fill_outlined;
        });
        return;
      }
      final diff = endLocal.difference(now);
      if (diff.inSeconds <= 0) {
        setState(() {
          _label = "ENDED";
          _timeString = "";
          _accentColor = AppTheme.textMuted;
          _icon = Icons.timer_off_outlined;
        });
      } else {
        setState(() {
          _label = widget.isJoined ? "PLAY NOW • ENDS IN:" : "ENDS IN:";
          _timeString = _formatDuration(diff);
          _accentColor = AppTheme.accentPurple;
          _icon = Icons.flash_on_outlined;
        });
      }
    } else {
      setState(() {
        _label = "CONTEST ENDED";
        _timeString = "";
        _accentColor = AppTheme.textMuted;
        _icon = Icons.timer_off_outlined;
      });
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$hours:$minutes:$seconds";
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    final month = months[dt.month - 1];
    final day = dt.day;
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? "PM" : "AM";
    return "$month $day, $hour:$minute $period";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _accentColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _icon,
            size: 14,
            color: _accentColor,
          ),
          const SizedBox(width: 6),
          Text(
            _label,
            style: GoogleFonts.inter(
              color: AppTheme.textMain.withOpacity(0.85),
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
          if (_timeString.isNotEmpty) ...[
            const SizedBox(width: 4),
            Text(
              _timeString,
              style: GoogleFonts.shareTechMono(
                color: _accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
