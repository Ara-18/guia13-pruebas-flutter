import '../models/product.dart';
import '../services/coupon_repository.dart';
import '../services/location_service.dart';
import '../services/stock_api_service.dart';
import 'exceptions.dart';

class CartTotal {
  final double subtotal;
  final double taxAmount;
  final double discountAmount;
  final double total;

  const CartTotal({
    required this.subtotal,
    required this.taxAmount,
    required this.discountAmount,
    required this.total,
  });
}

class InventoryManager {
  final StockApiService stockApiService;
  final LocationService locationService;
  final CouponRepository couponRepository;

  final Map<Product, int> _cart = {};

  InventoryManager({
    required this.stockApiService,
    required this.locationService,
    required this.couponRepository,
  });

  Map<Product, int> get cart => Map.unmodifiable(_cart);

  Future<void> addProduct(Product product, int quantity) async {
    final available = await stockApiService.getAvailableStock(product.id);
    final currentInCart = _cart[product] ?? 0;
    final totalRequested = currentInCart + quantity;

    if (totalRequested > available) {
      throw InsufficientStockException(
        productId: product.id,
        requested: totalRequested,
        available: available,
      );
    }

    _cart[product] = totalRequested;
  }

  Future<CartTotal> calculateTotal({String? couponCode}) async {
    final subtotal = _cart.entries.fold<double>(
      0.0,
          (sum, entry) => sum + (entry.key.price * entry.value),
    );

    final taxRate = await locationService.getTaxRateForCurrentRegion();
    final taxAmount = subtotal * taxRate;

    double discountAmount = 0.0;
    if (couponCode != null && couponCode.isNotEmpty) {
      final coupon = await couponRepository.findByCode(couponCode);
      if (coupon != null && !coupon.isExpired) {
        discountAmount = subtotal * coupon.discountPercentage;
      }
    }

    final total = subtotal + taxAmount - discountAmount;

    return CartTotal(
      subtotal: subtotal,
      taxAmount: taxAmount,
      discountAmount: discountAmount,
      total: total,
    );
  }
}