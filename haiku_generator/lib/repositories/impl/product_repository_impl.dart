import '../../models/product.dart';
import '../abstract/product_repository.dart';

class ProductRepositoryImpl implements ProductRepository {
  ProductRepositoryImpl();

  @override
  Future<List<Product>> getAllProduct() async {
    var dummyData = [
      {'productName': 'Google Search'},
      {'productName': 'YouTube'},
      {'productName': 'Android'},
      {'productName': 'Google Maps'},
      {'productName': 'GMail'}
    ];
    return dummyData.map((item) => Product.fromMap(item)).toList();
  }
}