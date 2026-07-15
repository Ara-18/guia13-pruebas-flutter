class InsufficientStockException implements Exception {
  final String productId;
  final int requested;
  final int available;

  InsufficientStockException({
    required this.productId,
    required this.requested,
    required this.available,
  });

  @override
  String toString() =>
      'InsufficientStockException: se solicitaron $requested unidades del '
          'producto "$productId" pero solo hay $available disponibles.';
}