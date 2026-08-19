import '../errors/app_exception.dart';

class PhoneNumberNormalizer {
  const PhoneNumberNormalizer._();

  static String normalizeVietnamesePhone(String value) {
    final compact = value.replaceAll(RegExp(r'[\s().-]'), '');
    if (compact.isEmpty) {
      throw const AppException('Phone number is required.');
    }

    if (compact.startsWith('+')) {
      return compact;
    }

    if (compact.startsWith('84')) {
      return '+$compact';
    }

    if (compact.startsWith('0') && compact.length >= 10) {
      return '+84${compact.substring(1)}';
    }

    throw const AppException('Phone number must use Vietnamese mobile format.');
  }
}
