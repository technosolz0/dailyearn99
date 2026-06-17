import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:de99_admin/core/network/api_client.dart';

class AdminContest {
  final int id;
  final String title;
  final double entryFee;
  final int totalSlots;
  final int joinedSlots;
  final double prizePool;
  final DateTime startTime;
  final DateTime? endTime;
  final String status;

  AdminContest({
    required this.id,
    required this.title,
    required this.entryFee,
    required this.totalSlots,
    required this.joinedSlots,
    required this.prizePool,
    required this.startTime,
    this.endTime,
    required this.status,
  });

  factory AdminContest.fromJson(Map<String, dynamic> json) {
    return AdminContest(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Quiz Contest',
      entryFee: (json['entry_fee'] ?? 0).toDouble(),
      totalSlots: json['total_slots'] ?? 0,
      joinedSlots: json['joined_slots'] ?? 0,
      prizePool: (json['prize_pool'] ?? 0).toDouble(),
      startTime: DateTime.parse(json['start_time']),
      endTime: json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      status: json['status'] ?? 'UPCOMING',
    );
  }
}

abstract class ContestsState {}

class ContestsInitial extends ContestsState {}
class ContestsLoading extends ContestsState {}
class ContestsLoaded extends ContestsState {
  final List<AdminContest> contests;
  ContestsLoaded(this.contests);
}
class ContestsError extends ContestsState {
  final String message;
  ContestsError(this.message);
}

class ContestsCubit extends Cubit<ContestsState> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();

  ContestsCubit() : super(ContestsInitial());

  Future<void> fetchContests() async {
    emit(ContestsLoading());
    try {
      final response = await _apiClient.dio.get('/contests');
      final list = (response.data as List).map((x) => AdminContest.fromJson(x)).toList();
      // Sort: active first, then upcoming, then completed
      list.sort((a, b) {
        if (a.status == b.status) {
          return b.startTime.compareTo(a.startTime);
        }
        if (a.status == 'ACTIVE') return -1;
        if (b.status == 'ACTIVE') return 1;
        if (a.status == 'UPCOMING') return -1;
        if (b.status == 'UPCOMING') return 1;
        return 0;
      });
      emit(ContestsLoaded(list));
    } on DioException catch (e) {
      String errMsg = 'Failed to load contests';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(ContestsError(errMsg));
    } catch (e) {
      emit(ContestsError(e.toString()));
    }
  }

  Future<void> createContest({
    required String title,
    required double entryFee,
    required int totalSlots,
    required double prizePool,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      await _apiClient.dio.post(
        '/admin/contests',
        data: {
          'title': title,
          'entry_fee': entryFee,
          'total_slots': totalSlots,
          'prize_pool': prizePool,
          'start_time': startTime.toUtc().toIso8601String(),
          'end_time': endTime.toUtc().toIso8601String(),
          'prize_rules': null,
          'questions': null, // Uses default database questions automatically
        },
      );
      await fetchContests(); // Refresh
    } on DioException catch (e) {
      String errMsg = 'Failed to create contest';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(ContestsError(errMsg));
    } catch (e) {
      emit(ContestsError(e.toString()));
    }
  }

  Future<void> completeContest(int contestId) async {
    try {
      await _apiClient.dio.post('/admin/contests/$contestId/complete');
      await fetchContests(); // Refresh
    } on DioException catch (e) {
      String errMsg = 'Failed to complete contest';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(ContestsError(errMsg));
    } catch (e) {
      emit(ContestsError(e.toString()));
    }
  }

  Future<void> deleteContest(int contestId) async {
    try {
      await _apiClient.dio.delete('/admin/contests/$contestId');
      await fetchContests(); // Refresh
    } on DioException catch (e) {
      String errMsg = 'Failed to delete contest';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(ContestsError(errMsg));
    } catch (e) {
      emit(ContestsError(e.toString()));
    }
  }
}
