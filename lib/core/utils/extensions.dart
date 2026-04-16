extension StringExtensions on String {
  /// Capitalize first letter
  String get capitalized {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }

  /// Check if email is valid
  bool get isValidEmail {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(this);
  }

  /// Check if password is strong
  bool get isStrongPassword {
    // At least 8 characters, 1 uppercase, 1 lowercase, 1 number
    return length >= 8 &&
        contains(RegExp(r'[A-Z]')) &&
        contains(RegExp(r'[a-z]')) &&
        contains(RegExp(r'[0-9]'));
  }

  /// Truncate string with ellipsis
  String truncate(int maxLength, {String ellipsis = '...'}) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength - ellipsis.length)}$ellipsis';
  }
}

extension IntExtensions on int {
  /// Convert seconds to readable time format (MM:SS or HH:MM:SS)
  String get toReadableTime {
    final minutes = toString().padLeft(2, '0');
    final seconds = remainder(60).toString().padLeft(2, '0');

    if (this < 3600) {
      return '$minutes:$seconds';
    }

    final hours = (this ~/ 3600).toString();
    return '$hours:${(remainder(3600) ~/ 60).toString().padLeft(2, '0')}:$seconds';
  }

  /// Format as currency
  String get toCurrency {
    return '\$${toStringAsFixed(2)}';
  }
}

extension DoubleExtensions on double {
  /// Convert seconds to readable time format
  String get toReadableTime {
    return toInt().toReadableTime;
  }

  /// Round to specific decimal places
  double roundTo(int places) {
    final mod = (10.0 * places).toInt();
    return ((this * mod).round() / mod);
  }

  /// Format as currency
  String get toCurrency {
    return '\$${toStringAsFixed(2)}';
  }
}

extension DateTimeExtensions on DateTime {
  /// Check if date is today
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }

  /// Check if date is yesterday
  bool get isYesterday {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return year == yesterday.year &&
        month == yesterday.month &&
        day == yesterday.day;
  }

  /// Get formatted date string (e.g., "Jan 15, 2024")
  String get formattedDate {
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
    return '${months[month - 1]} $day, $year';
  }

  /// Get relative time (e.g., "2 days ago")
  String get relativeTime {
    final now = DateTime.now();
    final difference = now.difference(this);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }
}

extension ListExtensions<T> on List<T> {
  /// Check if list is empty
  bool get isEmpty => length == 0;

  /// Get item at index or null
  T? getOrNull(int index) {
    if (index < 0 || index >= length) return null;
    return this[index];
  }
}
