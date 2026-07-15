import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_testing_lab/models/product.dart';
import 'package:flutter_testing_lab/models/coupon.dart';
import 'package:flutter_testing_lab/services/stock_api_service.dart';
import 'package:flutter_testing_lab/services/location_service.dart';
import 'package:flutter_testing_lab/services/coupon_repository.dart';
import 'package:flutter_testing_lab/inventory/inventory_manager.dart';
import 'package:flutter_testing_lab/inventory/exceptions.dart';

class MockStockApiService extends Mock implements StockApiService {}

class MockLocationService extends Mock implements LocationService {}

class MockCouponRepository extends Mock implements CouponRepository {}

void main() {
  late InventoryManager inventoryManager;
  late MockStockApiService mockStockApiService;
  late MockLocationService mockLocationService;
  late MockCouponRepository mockCouponRepository;

  final producto = const Product(id: 'p1', name: 'Laptop', price: 1000.0);

  setUp(() {
    mockStockApiService = MockStockApiService();
    mockLocationService = MockLocationService();
    mockCouponRepository = MockCouponRepository();

    inventoryManager = InventoryManager(
      stockApiService: mockStockApiService,
      locationService: mockLocationService,
      couponRepository: mockCouponRepository,
    );
  });

  group('InventoryManager - addProduct:', () {
    test('Debe agregar el producto al carrito si hay stock suficiente',
            () async {
          when(() => mockStockApiService.getAvailableStock('p1'))
              .thenAnswer((_) async => 10);

          await inventoryManager.addProduct(producto, 3);

          expect(inventoryManager.cart.length, 1);
          expect(inventoryManager.cart[producto], 3);
          verify(() => mockStockApiService.getAvailableStock('p1')).called(1);
        });

    test('Debe lanzar InsufficientStockException si la cantidad excede el stock',
            () async {
          when(() => mockStockApiService.getAvailableStock('p1'))
              .thenAnswer((_) async => 2);

          expect(
                () => inventoryManager.addProduct(producto, 5),
            throwsA(isA<InsufficientStockException>()),
          );
        });

    test('Debe acumular la cantidad si el producto ya existe en el carrito',
            () async {
          when(() => mockStockApiService.getAvailableStock('p1'))
              .thenAnswer((_) async => 10);

          await inventoryManager.addProduct(producto, 2);
          await inventoryManager.addProduct(producto, 3);

          expect(inventoryManager.cart.length, 1);
          expect(inventoryManager.cart[producto], 5);
        });

    test('Debe lanzar excepción si la suma acumulada excede el stock',
            () async {
          when(() => mockStockApiService.getAvailableStock('p1'))
              .thenAnswer((_) async => 4);

          await inventoryManager.addProduct(producto, 3);

          expect(
                () => inventoryManager.addProduct(producto, 3),
            throwsA(isA<InsufficientStockException>()),
          );
        });

    test('Debe registrar productos distintos como entradas separadas',
            () async {
          final producto2 = const Product(id: 'p2', name: 'Mouse', price: 50.0);

          when(() => mockStockApiService.getAvailableStock('p1'))
              .thenAnswer((_) async => 10);
          when(() => mockStockApiService.getAvailableStock('p2'))
              .thenAnswer((_) async => 10);

          await inventoryManager.addProduct(producto, 1);
          await inventoryManager.addProduct(producto2, 1);

          expect(inventoryManager.cart.length, 2);
        });
  });

  group('InventoryManager - calculateTotal:', () {
    setUp(() {
      when(() => mockStockApiService.getAvailableStock('p1'))
          .thenAnswer((_) async => 10);
    });

    test('Debe calcular subtotal, impuesto y total sin cupón', () async {
      when(() => mockLocationService.getTaxRateForCurrentRegion())
          .thenAnswer((_) async => 0.18);

      await inventoryManager.addProduct(producto, 1);
      final result = await inventoryManager.calculateTotal();

      expect(result.subtotal, 1000.0);
      expect(result.taxAmount, 180.0);
      expect(result.discountAmount, 0.0);
      expect(result.total, 1180.0);
    });

    test('Debe aplicar el descuento del cupón si es válido y no está vencido',
            () async {
          when(() => mockLocationService.getTaxRateForCurrentRegion())
              .thenAnswer((_) async => 0.18);
          when(() => mockCouponRepository.findByCode('DESC10')).thenAnswer(
                (_) async => Coupon(
              code: 'DESC10',
              discountPercentage: 0.10,
              expirationDate: DateTime.now().add(const Duration(days: 5)),
            ),
          );

          await inventoryManager.addProduct(producto, 1);
          final result =
          await inventoryManager.calculateTotal(couponCode: 'DESC10');

          expect(result.discountAmount, 100.0);
          expect(result.total, 1080.0); // 1000 + 180 - 100
        });

    test('No debe aplicar descuento si el cupón está vencido', () async {
      when(() => mockLocationService.getTaxRateForCurrentRegion())
          .thenAnswer((_) async => 0.18);
      when(() => mockCouponRepository.findByCode('VENCIDO')).thenAnswer(
            (_) async => Coupon(
          code: 'VENCIDO',
          discountPercentage: 0.20,
          expirationDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      await inventoryManager.addProduct(producto, 1);
      final result =
      await inventoryManager.calculateTotal(couponCode: 'VENCIDO');

      expect(result.discountAmount, 0.0);
      expect(result.total, 1180.0);
    });

    test('No debe aplicar descuento si el código de cupón no existe',
            () async {
          when(() => mockLocationService.getTaxRateForCurrentRegion())
              .thenAnswer((_) async => 0.18);
          when(() => mockCouponRepository.findByCode('NOEXISTE'))
              .thenAnswer((_) async => null);

          await inventoryManager.addProduct(producto, 1);
          final result =
          await inventoryManager.calculateTotal(couponCode: 'NOEXISTE');

          expect(result.discountAmount, 0.0);
          expect(result.total, 1180.0);
        });

    test('No debe intentar buscar cupón si el código es un string vacío',
            () async {
          when(() => mockLocationService.getTaxRateForCurrentRegion())
              .thenAnswer((_) async => 0.18);

          await inventoryManager.addProduct(producto, 1);
          final result = await inventoryManager.calculateTotal(couponCode: '');

          expect(result.discountAmount, 0.0);
          verifyNever(() => mockCouponRepository.findByCode(any()));
        });

    test('Debe calcular correctamente el total con múltiples productos',
            () async {
          final producto2 = const Product(id: 'p2', name: 'Mouse', price: 50.0);
          when(() => mockStockApiService.getAvailableStock('p2'))
              .thenAnswer((_) async => 10);
          when(() => mockLocationService.getTaxRateForCurrentRegion())
              .thenAnswer((_) async => 0.10);

          await inventoryManager.addProduct(producto, 1);
          await inventoryManager.addProduct(producto2, 2);

          final result = await inventoryManager.calculateTotal();

          // subtotal: 1000 + (50*2) = 1100
          expect(result.subtotal, 1100.0);
          expect(result.taxAmount, 110.0);
          expect(result.total, 1210.0);
        });
  });

  group('InsufficientStockException - toString:', () {
    test('Debe incluir productId, cantidad solicitada y disponible', () {
      final exception = InsufficientStockException(
        productId: 'p1',
        requested: 5,
        available: 2,
      );

      final mensaje = exception.toString();

      expect(mensaje, contains('p1'));
      expect(mensaje, contains('5'));
      expect(mensaje, contains('2'));
    });
  });

  group('Coupon - isExpired:', () {
    test('Debe retornar true si la fecha de expiración ya pasó', () {
      final coupon = Coupon(
        code: 'VIEJO',
        discountPercentage: 0.15,
        expirationDate: DateTime.now().subtract(const Duration(days: 1)),
      );

      expect(coupon.isExpired, isTrue);
    });

    test('Debe retornar false si la fecha de expiración es futura', () {
      final coupon = Coupon(
        code: 'NUEVO',
        discountPercentage: 0.15,
        expirationDate: DateTime.now().add(const Duration(days: 1)),
      );

      expect(coupon.isExpired, isFalse);
    });
  });
}