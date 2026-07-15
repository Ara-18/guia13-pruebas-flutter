import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_testing_lab/models/product.dart';
import 'package:flutter_testing_lab/exceptions/insufficient_stock_exception.dart';
import 'package:flutter_testing_lab/services/stock_api_service.dart';
import 'package:flutter_testing_lab/services/location_service.dart';
import 'package:flutter_testing_lab/repositories/coupon_repository.dart';
import 'package:flutter_testing_lab/managers/inventory_manager.dart';

class MockStockApiService extends Mock implements StockApiService {}

class MockLocationService extends Mock implements LocationService {}

class MockCouponRepository extends Mock implements CouponRepository {}

void main() {
  late InventoryManager inventoryManager;
  late MockStockApiService mockStockApiService;
  late MockLocationService mockLocationService;
  late MockCouponRepository mockCouponRepository;

  final producto = Product(id: 'p1', name: 'Laptop', price: 1000.0);

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

          expect(inventoryManager.itemCount, 1);
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

    test('Debe incrementar la cantidad si el producto ya existe en el carrito',
            () async {
          when(() => mockStockApiService.getAvailableStock('p1'))
              .thenAnswer((_) async => 10);

          await inventoryManager.addProduct(producto, 2);
          await inventoryManager.addProduct(producto, 3);

          expect(inventoryManager.itemCount, 1);
        });
  });

  group('InventoryManager - calculateTotal:', () {
    setUp(() {
      when(() => mockStockApiService.getAvailableStock('p1'))
          .thenAnswer((_) async => 10);
    });

    test('Debe calcular el total aplicando el impuesto regional sin cupón',
            () async {
          when(() => mockLocationService.getUserRegion())
              .thenAnswer((_) async => 'CUSCO');

          await inventoryManager.addProduct(producto, 1);
          final total = await inventoryManager.calculateTotal();

          expect(total, 1180.0);
        });

    test('Debe aplicar el descuento del cupón si es válido y no está vencido',
            () async {
          when(() => mockLocationService.getUserRegion())
              .thenAnswer((_) async => 'CUSCO');
          when(() => mockCouponRepository.getCouponByCode('DESC10')).thenAnswer(
                (_) async => Coupon(
              code: 'DESC10',
              discountPercentage: 10,
              expirationDate: DateTime.now().add(const Duration(days: 5)),
            ),
          );

          await inventoryManager.addProduct(producto, 1);
          final total = await inventoryManager.calculateTotal(couponCode: 'DESC10');

          expect(total, 1062.0);
        });

    test('No debe aplicar descuento si el cupón está vencido', () async {
      when(() => mockLocationService.getUserRegion())
          .thenAnswer((_) async => 'CUSCO');
      when(() => mockCouponRepository.getCouponByCode('VENCIDO')).thenAnswer(
            (_) async => Coupon(
          code: 'VENCIDO',
          discountPercentage: 20,
          expirationDate: DateTime.now().subtract(const Duration(days: 1)),
        ),
      );

      await inventoryManager.addProduct(producto, 1);
      final total =
      await inventoryManager.calculateTotal(couponCode: 'VENCIDO');

      expect(total, 1180.0);
    });

    test('No debe aplicar descuento si el código de cupón no existe', () async {
      when(() => mockLocationService.getUserRegion())
          .thenAnswer((_) async => 'CUSCO');
      when(() => mockCouponRepository.getCouponByCode('NOEXISTE'))
          .thenAnswer((_) async => null);

      await inventoryManager.addProduct(producto, 1);
      final total =
      await inventoryManager.calculateTotal(couponCode: 'NOEXISTE');

      expect(total, 1180.0);
    });

    test('Debe aplicar 0% de impuesto para región EXTRANJERO', () async {
      when(() => mockLocationService.getUserRegion())
          .thenAnswer((_) async => 'EXTRANJERO');

      await inventoryManager.addProduct(producto, 1);
      final total = await inventoryManager.calculateTotal();

      expect(total, 1000.0);
    });

    test('Debe usar 18% por defecto si la región no está registrada',
            () async {
          when(() => mockLocationService.getUserRegion())
              .thenAnswer((_) async => 'DESCONOCIDA');

          await inventoryManager.addProduct(producto, 1);
          final total = await inventoryManager.calculateTotal();

          expect(total, 1180.0);
        });
  });

  group('InventoryManager - clearCart:', () {
    test('Debe vaciar el carrito y dejar itemCount en 0', () async {
      when(() => mockStockApiService.getAvailableStock('p1'))
          .thenAnswer((_) async => 10);

      await inventoryManager.addProduct(producto, 1);
      expect(inventoryManager.itemCount, 1);

      inventoryManager.clearCart();

      expect(inventoryManager.itemCount, 0);
    });
  });

  group('InventoryManager - multiples productos:', () {
    test('Debe registrar productos distintos como items separados', () async {
      final producto2 = Product(id: 'p2', name: 'Mouse', price: 50.0);

      when(() => mockStockApiService.getAvailableStock('p1'))
          .thenAnswer((_) async => 10);
      when(() => mockStockApiService.getAvailableStock('p2'))
          .thenAnswer((_) async => 10);

      await inventoryManager.addProduct(producto, 1);
      await inventoryManager.addProduct(producto2, 1);

      expect(inventoryManager.itemCount, 2);
    });
  });

  group('InsufficientStockException - toString:', () {
    test('Debe incluir el mensaje descriptivo en el toString', () {
      final exception =
      InsufficientStockException('Stock insuficiente para Laptop');

      expect(exception.toString(), contains('Stock insuficiente para Laptop'));
    });
  });
}