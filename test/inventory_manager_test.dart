import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter_testing_lab/models/coupon.dart';
import 'package:flutter_testing_lab/models/product.dart';
import 'package:flutter_testing_lab/inventory/exceptions.dart';
import 'package:flutter_testing_lab/inventory/inventory_manager.dart';
import 'package:flutter_testing_lab/services/coupon_repository.dart';
import 'package:flutter_testing_lab/services/location_service.dart';
import 'package:flutter_testing_lab/services/stock_api_service.dart';

class MockStockApiService extends Mock implements StockApiService {}
class MockLocationService extends Mock implements LocationService {}
class MockCouponRepository extends Mock implements CouponRepository {}

void main() {
  late InventoryManager manager;
  late MockStockApiService mockStockApi;
  late MockLocationService mockLocationService;
  late MockCouponRepository mockCouponRepository;

  const laptop = Product(id: 'p-001', name: 'Laptop', price: 1000.0);

  setUp(() {
    mockStockApi = MockStockApiService();
    mockLocationService = MockLocationService();
    mockCouponRepository = MockCouponRepository();

    manager = InventoryManager(
      stockApiService: mockStockApi,
      locationService: mockLocationService,
      couponRepository: mockCouponRepository,
    );
  });

  group('InventoryManager - addProduct:', () {
    test('Debe agregar el producto al carrito cuando hay stock suficiente', () async {
      when(() => mockStockApi.getAvailableStock('p-001')).thenAnswer((_) async => 10);
      await manager.addProduct(laptop, 3);
      expect(manager.cart[laptop], 3);
      verify(() => mockStockApi.getAvailableStock('p-001')).called(1);
    });

    test('Debe lanzar InsufficientStockException si la cantidad excede el stock', () async {
      when(() => mockStockApi.getAvailableStock('p-001')).thenAnswer((_) async => 2);
      expect(() => manager.addProduct(laptop, 5), throwsA(isA<InsufficientStockException>()));
    });

    test('Debe acumular cantidades ya existentes en el carrito antes de validar el stock', () async {
      when(() => mockStockApi.getAvailableStock('p-001')).thenAnswer((_) async => 5);
      await manager.addProduct(laptop, 3);
      expect(() => manager.addProduct(laptop, 3), throwsA(isA<InsufficientStockException>()));
    });
  });

  group('InventoryManager - calculateTotal:', () {
    test('Debe calcular el total aplicando la tasa impositiva regional sin cupón', () async {
      when(() => mockStockApi.getAvailableStock('p-001')).thenAnswer((_) async => 10);
      when(() => mockLocationService.getTaxRateForCurrentRegion()).thenAnswer((_) async => 0.18);

      await manager.addProduct(laptop, 2);
      final result = await manager.calculateTotal();

      expect(result.subtotal, 2000.0);
      expect(result.taxAmount, closeTo(360.0, 0.001));
      expect(result.discountAmount, 0.0);
      expect(result.total, closeTo(2360.0, 0.001));
    });

    test('Debe aplicar el descuento cuando el cupón es válido y no ha vencido', () async {
      when(() => mockStockApi.getAvailableStock('p-001')).thenAnswer((_) async => 10);
      when(() => mockLocationService.getTaxRateForCurrentRegion()).thenAnswer((_) async => 0.10);
      when(() => mockCouponRepository.findByCode('DESCUENTO10')).thenAnswer(
            (_) async => Coupon(
          code: 'DESCUENTO10',
          discountPercentage: 0.10,
          expirationDate: DateTime.now().add(const Duration(days: 5)),
        ),
      );

      await manager.addProduct(laptop, 1);
      final result = await manager.calculateTotal(couponCode: 'DESCUENTO10');

      expect(result.discountAmount, closeTo(100.0, 0.001));
      expect(result.total, closeTo(1000.0, 0.001));
    });

    test('No debe aplicar descuento si el cupón está vencido', () async {
      when(() => mockStockApi.getAvailableStock('p-001')).thenAnswer((_) async => 10);
      when(() => mockLocationService.getTaxRateForCurrentRegion()).thenAnswer((_) async => 0.10);
      when(() => mockCouponRepository.findByCode('VENCIDO')).thenAnswer(
            (_) async => Coupon(
          code: 'VENCIDO',
          discountPercentage: 0.20,
          expirationDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      await manager.addProduct(laptop, 1);
      final result = await manager.calculateTotal(couponCode: 'VENCIDO');

      expect(result.discountAmount, 0.0);
    });

    test('No debe aplicar descuento si el código de cupón no existe', () async {
      when(() => mockStockApi.getAvailableStock('p-001')).thenAnswer((_) async => 10);
      when(() => mockLocationService.getTaxRateForCurrentRegion()).thenAnswer((_) async => 0.10);
      when(() => mockCouponRepository.findByCode('NOEXISTE')).thenAnswer((_) async => null);

      await manager.addProduct(laptop, 1);
      final result = await manager.calculateTotal(couponCode: 'NOEXISTE');

      expect(result.discountAmount, 0.0);
      expect(result.total, closeTo(1100.0, 0.001));
    });
  });
}