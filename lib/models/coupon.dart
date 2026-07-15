class Coupon {
  final String code;
  final double discountPercentage; // 0.0 a 1.0
  final DateTime expirationDate;

  const Coupon({
    required this.code,
    required this.discountPercentage,
    required this.expirationDate,
  });

  bool get isExpired => DateTime.now().isAfter(expirationDate);
}