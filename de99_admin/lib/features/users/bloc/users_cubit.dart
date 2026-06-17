import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:de99_admin/core/network/api_client.dart';

class AdminUser {
  final int id;
  final String? name;
  final String? firstName;
  final String? lastName;
  final String phone;
  final String? email;
  final String referralCode;
  final String? referredBy;
  final double depositBalance;
  final double winningBalance;
  final double bonusBalance;
  final String kycStatus;
  final bool isBanned;
  final String? deviceDetails;
  
  final String? bankAccountNumber;
  final String? bankIfscCode;
  final String? bankAccountHolderName;
  final String? bankName;

  final List<dynamic> joinedContestIds;
  final List<dynamic> completedContestIds;
  final List<dynamic> joinedWordContestIds;
  final List<dynamic> completedWordContestIds;
  final List<dynamic> joinedPuzzleContestIds;
  final List<dynamic> completedPuzzleContestIds;
  final List<dynamic> joinedFruitContestIds;
  final List<dynamic> completedFruitContestIds;
  final List<dynamic> joinedArrowContestIds;
  final List<dynamic> completedArrowContestIds;

  AdminUser({
    required this.id,
    this.name,
    this.firstName,
    this.lastName,
    required this.phone,
    this.email,
    required this.referralCode,
    this.referredBy,
    required this.depositBalance,
    required this.winningBalance,
    required this.bonusBalance,
    required this.kycStatus,
    required this.isBanned,
    this.deviceDetails,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.bankAccountHolderName,
    this.bankName,
    required this.joinedContestIds,
    required this.completedContestIds,
    required this.joinedWordContestIds,
    required this.completedWordContestIds,
    required this.joinedPuzzleContestIds,
    required this.completedPuzzleContestIds,
    required this.joinedFruitContestIds,
    required this.completedFruitContestIds,
    required this.joinedArrowContestIds,
    required this.completedArrowContestIds,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] ?? 0,
      name: json['name'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      phone: json['phone'] ?? '',
      email: json['email'],
      referralCode: json['referral_code'] ?? '',
      referredBy: json['referred_by'],
      depositBalance: (json['deposit_balance'] ?? 0).toDouble(),
      winningBalance: (json['winning_balance'] ?? 0).toDouble(),
      bonusBalance: (json['bonus_balance'] ?? 0).toDouble(),
      kycStatus: json['kyc_status'] ?? 'PENDING',
      isBanned: json['is_banned'] ?? false,
      deviceDetails: json['device_details'],
      bankAccountNumber: json['bank_account_number'],
      bankIfscCode: json['bank_ifsc_code'],
      bankAccountHolderName: json['bank_account_holder_name'],
      bankName: json['bank_name'],
      joinedContestIds: json['joined_contest_ids'] ?? [],
      completedContestIds: json['completed_contest_ids'] ?? [],
      joinedWordContestIds: json['joined_word_contest_ids'] ?? [],
      completedWordContestIds: json['completed_word_contest_ids'] ?? [],
      joinedPuzzleContestIds: json['joined_puzzle_contest_ids'] ?? [],
      completedPuzzleContestIds: json['completed_puzzle_contest_ids'] ?? [],
      joinedFruitContestIds: json['joined_fruit_contest_ids'] ?? [],
      completedFruitContestIds: json['completed_fruit_contest_ids'] ?? [],
      joinedArrowContestIds: json['joined_arrow_contest_ids'] ?? [],
      completedArrowContestIds: json['completed_arrow_contest_ids'] ?? [],
    );
  }
}

abstract class UsersState {}

class UsersInitial extends UsersState {}
class UsersLoading extends UsersState {}
class UsersLoaded extends UsersState {
  final List<AdminUser> allUsers;
  final List<AdminUser> filteredUsers;
  final String searchQuery;
  UsersLoaded(this.allUsers, this.filteredUsers, {this.searchQuery = ''});
}
class UsersError extends UsersState {
  final String message;
  UsersError(this.message);
}

class UsersCubit extends Cubit<UsersState> {
  final ApiClient _apiClient = GetIt.instance<ApiClient>();

  UsersCubit() : super(UsersInitial());

  Future<void> fetchUsers() async {
    final currentQuery = (state is UsersLoaded) ? (state as UsersLoaded).searchQuery : '';
    emit(UsersLoading());
    try {
      final response = await _apiClient.dio.get('/admin/users');
      final users = (response.data as List).map((x) => AdminUser.fromJson(x)).toList();
      users.sort((a, b) => b.id.compareTo(a.id));
      _filterAndEmit(users, currentQuery);
    } on DioException catch (e) {
      String errMsg = 'Failed to load users';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(UsersError(errMsg));
    } catch (e) {
      emit(UsersError(e.toString()));
    }
  }

  void searchUsers(String query) {
    if (state is UsersLoaded) {
      final loaded = state as UsersLoaded;
      _filterAndEmit(loaded.allUsers, query);
    }
  }

  void _filterAndEmit(List<AdminUser> allUsers, String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      emit(UsersLoaded(allUsers, allUsers, searchQuery: query));
    } else {
      final filtered = allUsers.where((u) {
        final nameMatch = u.name?.toLowerCase().contains(cleanQuery) ?? false;
        final phoneMatch = u.phone.contains(cleanQuery);
        final refMatch = u.referralCode.toLowerCase().contains(cleanQuery);
        return nameMatch || phoneMatch || refMatch;
      }).toList();
      emit(UsersLoaded(allUsers, filtered, searchQuery: query));
    }
  }

  Future<void> toggleBan(int userId, bool ban) async {
    try {
      await _apiClient.dio.post('/admin/users/$userId/ban?ban=$ban');
      await fetchUsers(); // Reload lists
    } on DioException catch (e) {
      String errMsg = 'Failed to ban/unban user';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(UsersError(errMsg));
    } catch (e) {
      emit(UsersError(e.toString()));
    }
  }

  Future<void> adjustBalance(int userId, String walletType, double amount) async {
    try {
      await _apiClient.dio.post(
        '/admin/users/$userId/adjust-balance',
        data: {
          'wallet_type': walletType,
          'amount': amount,
        },
      );
      await fetchUsers(); // Reload lists
    } on DioException catch (e) {
      String errMsg = 'Failed to adjust balance';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(UsersError(errMsg));
    } catch (e) {
      emit(UsersError(e.toString()));
    }
  }

  Future<void> deleteUser(int userId) async {
    try {
      await _apiClient.dio.delete('/admin/users/$userId');
      await fetchUsers(); // Reload lists
    } on DioException catch (e) {
      String errMsg = 'Failed to delete user';
      if (e.response != null) {
        errMsg = e.response?.data['detail'] ?? errMsg;
      }
      emit(UsersError(errMsg));
    } catch (e) {
      emit(UsersError(e.toString()));
    }
  }
}
