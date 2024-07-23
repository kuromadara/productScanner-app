enum ProductType { teaTypeOne, teaTypeTwo, biscuit }

class ProductTypeHelper {
  static String getName(ProductType type) {
    switch (type) {
      case ProductType.teaTypeOne:
        return 'Tea Type One';
      case ProductType.teaTypeTwo:
        return 'Tea Type Two';
      case ProductType.biscuit:
        return 'Biscuit';
    }
  }

  static int getLineCount(ProductType type) {
    switch (type) {
      case ProductType.teaTypeOne:
        return 1;
      case ProductType.teaTypeTwo:
        return 2;
      case ProductType.biscuit:
        return 3;
    }
  }

  static bool isBatchNumber(ProductType type) {
    return type == ProductType.teaTypeOne || type == ProductType.teaTypeTwo;
  }
}
