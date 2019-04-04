import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:scoped_model/scoped_model.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rxdart/subjects.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';

import '../models/product.dart';
import '../models/user.dart';
import '../models/auth.dart';
import '../models/location_data.dart';

mixin ConnectedProductsModel on Model {
  List<Product> _products = [];
  User _authenticatedUser;
  String _selectedProductId;
  bool _isLoading = false;
}

mixin ProductsModel on ConnectedProductsModel {
  bool _showFavorites = false;

  List<Product> get allProducts {
    return List.from(_products);
  }

  List<Product> get displayProducts {
    if (_showFavorites) {
      return _products.where((Product product) => product.isFavorite).toList();
    }
    return List.from(_products);
  }

  bool get displayFavoriteOnly {
    return _showFavorites;
  }

  String get selectedProductId {
    return _selectedProductId;
  }

  Product get selectedProduct {
    if (selectedProductId == null) {
      return null;
    }
    return _products.firstWhere((Product product) {
      return product.id == _selectedProductId;
    });
  }

  Future<Map<String, dynamic>> uploadImage(File image,
      {String imagePath}) async {
    final mimeTypeData = lookupMimeType(image.path).split('/');
    final imageUploadRequest = http.MultipartRequest(
        'POST',
        Uri.parse(
            'https://us-central1-flutter-easylist-e6ef6.cloudfunctions.net/storeImage'));
    final file = await http.MultipartFile.fromPath('image', image.path,
        contentType: MediaType(mimeTypeData[0], mimeTypeData[1]));
    imageUploadRequest.files.add(file);
    if (imagePath != null) {
      imageUploadRequest.fields['imagePath'] = Uri.encodeComponent(imagePath);
    }
    imageUploadRequest.headers['Authorization'] =
        'Bearer ${_authenticatedUser.token}';
    try {
      final streamResponse = await imageUploadRequest.send();
      final response = await http.Response.fromStream(streamResponse);
      if (response.statusCode != 200 && response.statusCode != 201) {
        print('Something went wrong');
        print(json.decode(response.body));
        return null;
      }
      final responseData = json.decode(response.body);
      return responseData;
    } catch (error) {
      print(error);
      return null;
    }
  }

  Future<bool> addProduct(String title, String description, File image,
      double price, LocationData locationData) async {
    _isLoading = true;
    notifyListeners();
    final Map<String, dynamic> uploadData = await uploadImage(image);
    if (uploadData == null) {
      print('Upload failed!');
      return false;
    }
    final Map<String, dynamic> productData = {
      'title': title,
      'description': description,
      'price': price,
      'userEmail': _authenticatedUser.email,
      'imagePath': uploadData['imagePath'],
      'imageUrl': uploadData['imageUrl'],
      'userId': _authenticatedUser.id,
      'loc_lat': locationData.latitude,
      'loc_lng': locationData.longitude,
      'loc_address': locationData.address,
    };
    try {
      final http.Response response = await http.post(
          'https://flutter-easylist-e6ef6.firebaseio.com/products.json?auth=${_authenticatedUser.token}',
          body: json.encode(productData));

      if (response.statusCode != 200 && response.statusCode != 201) {
        _isLoading = false;
        notifyListeners();
        return false;
      }
      final Map<String, dynamic> responseData = json.decode(response.body);
      final Product newProduct = Product(
          id: responseData['name'],
          title: title,
          description: description,
          imageUrl: uploadData['imageUrl'],
          imagePath: uploadData['imagePath'],
          price: price,
          location: locationData,
          userEmail: _authenticatedUser.email,
          userId: _authenticatedUser.id);
      _products.add(newProduct);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(String title, String description, File image,
      double price, LocationData locationData) async {
    _isLoading = true;
    notifyListeners();
    String imageUrl = selectedProduct.imageUrl;
    String imagePath = selectedProduct.imagePath;
    if (image != null) {
      final Map<String, dynamic> uploadData = await uploadImage(image);
      if (uploadData == null) {
        print('Upload failed!');
        return false;
      }
      imagePath = uploadData['imagePath'];
      imageUrl = uploadData['imageUrl'];
    }
    final Map<String, dynamic> updateData = {
      'title': title,
      'description': description,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'price': price,
      'userEmail': selectedProduct.userEmail,
      'userId': selectedProduct.userId,
      'loc_lat': locationData.latitude,
      'loc_lng': locationData.longitude,
      'loc_address': locationData.address,
    };
    return http
        .put(
            'https://flutter-easylist-e6ef6.firebaseio.com/products/${selectedProduct.id}.json?auth=${_authenticatedUser.token}',
            body: json.encode(updateData))
        .then((http.Response response) {
      _isLoading = false;
      final Product newProduct = Product(
          id: selectedProduct.id,
          title: title,
          description: description,
          imageUrl: imageUrl,
          imagePath: imagePath,
          price: price,
          location: locationData,
          userEmail: selectedProduct.userEmail,
          userId: selectedProduct.userId);
      _products[selectedProductIndex] = newProduct;
      notifyListeners();
      return true;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
      return false;
    });
  }

  int get selectedProductIndex {
    return _products.indexWhere((Product product) {
      return product.id == _selectedProductId;
    });
  }

  Future<bool> deleteProduct() {
    _isLoading = true;
    final deletedProductId = selectedProduct.id;
    _products.removeAt(selectedProductIndex);
    _selectedProductId = null;
    notifyListeners();
    return http
        .delete(
            'https://flutter-easylist-e6ef6.firebaseio.com/products/$deletedProductId.json?auth=${_authenticatedUser.token}')
        .then((http.Response response) {
      _isLoading = false;
      notifyListeners();
      return true;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
      return false;
    });
  }

  Future<Null> fectchProducts({onlyForUser = false, clearExisting = false}) {
    _isLoading = true;
    if (clearExisting) {
      _products = [];
    }

    notifyListeners();
    return http
        .get(
            'https://flutter-easylist-e6ef6.firebaseio.com/products.json?auth=${_authenticatedUser.token}')
        .then<Null>((http.Response response) {
      final List<Product> fetchProductList = [];
      final Map<String, dynamic> productListData = json.decode(response.body);
      if (productListData == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }
      productListData.forEach((String productId, dynamic productData) {
        final Product product = Product(
            id: productId,
            title: productData['title'],
            description: productData['description'],
            imageUrl: productData['imageUrl'],
            imagePath: productData['imagePath'],
            price: productData['price'],
            location: LocationData(productData['loc_lat'],
                productData['loc_lng'], productData['loc_address']),
            userEmail: productData['userEmail'],
            userId: productData['userId'],
            isFavorite: productData['favoriteUserList'] == null
                ? false
                : (productData['favoriteUserList'] as Map<String, dynamic>)
                    .containsKey(_authenticatedUser.id));
        fetchProductList.add(product);
      });
      _products = fetchProductList.where((Product product) {
        if (onlyForUser) {
          return _authenticatedUser.id == product.userId;
        } else
          return true;
      }).toList();
      _isLoading = false;
      notifyListeners();
      _selectedProductId = null;
    }).catchError((error) {
      _isLoading = false;
      notifyListeners();
      return;
    });
  }

  void selectProduct(String productId) {
    _selectedProductId = productId;
    if (productId != null) {
      notifyListeners();
    }
  }

  void toggleProductFavoriteStatus() async {
    final bool isCurrentlyFavorite = selectedProduct.isFavorite;
    final bool newFavoriteStatus = !isCurrentlyFavorite;
    final Product updatedProduct = Product(
      id: selectedProduct.id,
      title: selectedProduct.title,
      description: selectedProduct.description,
      price: selectedProduct.price,
      imageUrl: selectedProduct.imageUrl,
      imagePath: selectedProduct.imagePath,
      userEmail: selectedProduct.userEmail,
      userId: selectedProduct.userId,
      location: selectedProduct.location,
      isFavorite: newFavoriteStatus,
    );
    _products[selectedProductIndex] = updatedProduct;
    http.Response response;
    if (newFavoriteStatus) {
      response = await http.put(
          'https://flutter-easylist-e6ef6.firebaseio.com/products/${selectedProduct.id}/favoriteListUsers/${_authenticatedUser.id}.json?auth=${_authenticatedUser.token}',
          body: json.encode(true));
    } else {
      response = await http.delete(
        'https://flutter-easylist-e6ef6.firebaseio.com/products/${selectedProduct.id}/favoriteListUsers/${_authenticatedUser.id}.json?auth=${_authenticatedUser.token}',
      );
    }
    if (response.statusCode != 200 && response.statusCode != 201) {
      final Product updatedProduct = Product(
        id: selectedProduct.id,
        title: selectedProduct.title,
        description: selectedProduct.description,
        price: selectedProduct.price,
        imageUrl: selectedProduct.imageUrl,
        imagePath: selectedProduct.imagePath,
        userEmail: selectedProduct.userEmail,
        userId: selectedProduct.userId,
        location: selectedProduct.location,
        isFavorite: !newFavoriteStatus,
      );
      _products[selectedProductIndex] = updatedProduct;
      notifyListeners();
    }
    _selectedProductId = null;
  }

  void toggleDisplayMode() {
    _showFavorites = !_showFavorites;
    notifyListeners();
  }
}

mixin UserModel on ConnectedProductsModel {
  Timer _authTimer;
  PublishSubject<bool> _userSubject = PublishSubject();

  User get user {
    return _authenticatedUser;
  }

  PublishSubject<bool> get userSubject {
    return _userSubject;
  }

  void logout() async {
    _authenticatedUser = null;
    _authTimer.cancel();
    _selectedProductId = null;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove('token');
    prefs.remove('userEmail');
    prefs.remove('userId');
    prefs.remove('expiresIn');
    _userSubject.add(false);
  }

  Future<Map<String, dynamic>> authenticate(String email, String password,
      [AuthMode mode = AuthMode.Login]) async {
    _isLoading = true;
    notifyListeners();
    final Map<String, dynamic> authData = {
      'email': email,
      'password': password,
      'returnSecureToken': true,
    };
    http.Response response;
    if (mode == AuthMode.Login) {
      response = await http.post(
          'https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyPassword?key=AIzaSyBKRsXfz4dW_11Lk1YWYnQcqw2rVEX8lLM',
          body: json.encode(authData),
          headers: {'Content-Type': 'application/json'});
    } else {
      response = await http.post(
        'https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=AIzaSyBKRsXfz4dW_11Lk1YWYnQcqw2rVEX8lLM',
        body: json.encode(authData),
        headers: {'Content-Type': 'application/json'},
      );
    }
    final Map<String, dynamic> responseData = json.decode(response.body);
    bool hasError = true;
    String message = 'Something went wrong.';
    if (responseData.containsKey('idToken')) {
      hasError = false;
      message = 'Authentication succeeded!';
      _authenticatedUser = User(
          id: responseData['localId'],
          email: email,
          token: responseData['idToken']);
      setAuthTimeout(int.parse(responseData['expiresIn']));
      final DateTime now = DateTime.now();
      final DateTime expiryTime =
          now.add(Duration(seconds: int.parse(responseData['expiresIn'])));
      _userSubject.add(true);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      prefs.setString('token', responseData['idToken']);
      prefs.setString('userEmail', email);
      prefs.setString('userId', responseData['localId']);
      prefs.setString('expiryTime', expiryTime.toIso8601String());
    } else if (responseData['error']['message'] == 'EMAIL_NOT_FOUND') {
      message = 'There is no user record corresponding to this identifier.';
    } else if (responseData['error']['message'] == 'INVALID_PASSWORD') {
      message = 'The password is invalid.';
    } else if (responseData['error']['message'] == 'USER_DISABLED') {
      message = 'The user account has been disabled by an administrator.';
    } else if (responseData['error']['message'] == 'EMAIL_EXISTS') {
      message = 'The email address is already in use by another account.';
    } else if (responseData['error']['message'] == 'OPERATION_NOT_ALLOWED') {
      message = 'Password sign-in is disabled for this project.';
    } else if (responseData['error']['message'] ==
        'TOO_MANY_ATTEMPTS_TRY_LATER') {
      message =
          'We have blocked all requests from this device due to unusual activity. Try again later.';
    }
    _isLoading = false;
    notifyListeners();
    return {
      'success': !hasError,
      'message': message,
    };
  }

  void autoAuthenticate() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('token');
    final String expiryTimeString = prefs.getString('expiryTime');
    if (token != null) {
      final DateTime now = DateTime.now();
      final parsedExpiryTime = DateTime.parse(expiryTimeString);
      if (parsedExpiryTime.isBefore(now)) {
        _authenticatedUser = null;
        notifyListeners();
        return;
      }
      final int tokenLifespan = parsedExpiryTime.difference(now).inSeconds;
      _authenticatedUser = User(
          id: prefs.getString('userId'),
          email: prefs.getString('userEmail'),
          token: token);
      _userSubject.add(true);
      setAuthTimeout(tokenLifespan);
      notifyListeners();
    }
  }

  void setAuthTimeout(int time) {
    _authTimer = Timer(Duration(seconds: time), () {
      logout();
    });
  }
}

mixin UtilityModel on ConnectedProductsModel {
  bool get isLoading {
    return _isLoading;
  }
}
