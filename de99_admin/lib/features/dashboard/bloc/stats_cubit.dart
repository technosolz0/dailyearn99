import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:de99_admin/core/network/api_client.dart';

class AdminStats {
  final int totalUsers;
  final double totalRevenue;
  final double totalDeposits;
  final double totalWinningsPaid;
  final int activeContests;

  AdminStats({
    required this.totalUsers,
    required this.totalRevenue,
    required this.totalDeposits,
    required this.totalWinningsPaid,
    required this.activeContests,
  });

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      totalUsers: json['total_users'] ?? 0,
      totalRevenue: (json['total_revenue'] ?? 0).toDouble(),
      totalDeposits: (json['total_deposits'] ?? 0).toDouble(),
      totalWinningsPaid: (json['total_winnings_paid'] ?? 0).toDouble(),
      activeContests: json['active_contests'] ?? 0,
    );
  }
}

abstract class StatsState {}

class StatsInitial extends StatsState {}
class StatsLoading extends StatsState {}
class StatsLoaded extends StatsState {
  final AdminStats stats;
  StatsLoaded(this.stats);
}
class StatsError extends StatsState {
  final String message;
  StatsError(this.message);
}

class StatsCubit extends Cubit<StatsState> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();

  StatsCubit() : super(StatsInitial());

  Future<void> fetchStats() async {
    emit(StatsLoading());
    try {
      final response = await _apiClient.dio.get('/admin/stats');
      final stats = AdminStats.fromJson(response.data);
      emit(StatsLoaded(stats));
    } on DioException catch (e) {
      String errMsg = 'Failed to fetch dashboard stats';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      } else {
        errMsg = e.message ?? errMsg;
      }
      emit(StatsError(errMsg));
    } catch (e) {
      emit(StatsError(e.toString()));
    }
  }
}
