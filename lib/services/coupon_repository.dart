import '../models/coupon.dart';

abstract class CouponRepository {
  Future<Coupon?> findByCode(String code);
}