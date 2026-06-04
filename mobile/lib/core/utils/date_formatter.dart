String formatContestDateTime(DateTime dateTime) {
  final localTime = dateTime.toLocal();
  final hour24 = localTime.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = localTime.minute.toString().padLeft(2, '0');

  final day = localTime.day;
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final month = months[localTime.month - 1];
  final year = localTime.year;

  return '$day $month $year, $hour12:$minute $period';
}
