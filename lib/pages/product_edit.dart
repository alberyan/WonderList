import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';

import 'package:scoped_model/scoped_model.dart';

import '../widgets/helpers/ensure-visible.dart';
import '../widgets/form_inputs/location.dart';
import '../widgets/form_inputs/image.dart';
import '../widgets/ui_element/adaptive_progress_indicator.dart';
import '../models/product.dart';
import '../scoped_models/main.dart';
import '../models/location_data.dart';

class ProductEditPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _ProductEditPageState();
  }
}

class _ProductEditPageState extends State<ProductEditPage> {
  final Map<String, dynamic> _formData = {
    'title': null,
    'description': null,
    'price': null,
    'image': null,
    'location': null,
  };
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();

  final _titleTextController = TextEditingController();
  final _descriptionTextController = TextEditingController();
  final _priceTextController = TextEditingController();

  Widget _buildTitleTextField(Product product) {
    if (_titleTextController.text == '') {
      if (product == null) {
        _titleTextController.text = '';
      } else {
        _titleTextController.text = product.title;
      }
    }
    return EnsureVisibleWhenFocused(
      focusNode: _titleFocusNode,
      child: TextFormField(
        focusNode: _titleFocusNode,
        decoration: InputDecoration(
          labelText: 'Product Title',
        ),
        controller: _titleTextController,
        // initialValue: product == null ? '' : product.title,
        validator: (String value) {
          if (value.isEmpty || value.length < 5) {
            return 'Title is required and should be longer than 4 characters';
          }
        },
      ),
    );
  }

  Widget _buildDescriptionTextField(Product product) {
    if (_descriptionTextController.text == '') {
      if (product == null) {
        _descriptionTextController.text = '';
      } else {
        _descriptionTextController.text = product.description;
      }
    }
    return EnsureVisibleWhenFocused(
      focusNode: _descriptionFocusNode,
      child: TextFormField(
        focusNode: _descriptionFocusNode,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: 'Product Description',
        ),
        // initialValue: product == null ? '' : product.description,
        controller: _descriptionTextController,
        validator: (String value) {
          if (value.isEmpty || value.length <= 10) {
            return 'Description is required and should be longer than 10 characters';
          }
        },
      ),
    );
  }

  Widget _buildPriceTextField(Product product) {
    if (_priceTextController.text == '') {
      if (product == null) {
        _priceTextController.text = '';
      } else {
        _priceTextController.text = product.price.toString();
      }
    }
    return EnsureVisibleWhenFocused(
      focusNode: _priceFocusNode,
      child: TextFormField(
        focusNode: _priceFocusNode,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Product Price',
        ),
        controller: _priceTextController,
        validator: (String value) {
          if (value.isEmpty ||
              !RegExp(r'^(?:[1-9]\d*|0)?(?:[,.]\d+)?$').hasMatch(value)) {
            return 'Price is required and should be a number.';
          }
        },
        onSaved: (String value) {
          // _formData['price'] = double.parse(value);
        },
      ),
    );
  }

  void _setLocation(LocationData locationData) {
    _formData['location'] = locationData;
  }

  void _setImage(File image) {
    _formData['image'] = image;
  }

  void _submitForm(MainModel model) {
    if (!_formKey.currentState.validate() ||
        (_formData['image'] == null && model.selectedProductIndex == -1)) {
      return;
    }
    _formKey.currentState.save();
    if (model.selectedProductIndex == -1) {
      model
          .addProduct(
              _titleTextController.text,
              _descriptionTextController.text,
              _formData['image'],
              double.parse(
                  _priceTextController.text.replaceFirst(RegExp(r','), '.')),
              _formData['location'])
          .then((bool success) {
        if (success) {
          Navigator.pushReplacementNamed(context, '/products')
              .then((_) => model.selectProduct(null));
        } else {
          showDialog(
            builder: (BuildContext context) {
              return AlertDialog(
                content: Text('Please try again'),
                actions: <Widget>[
                  FlatButton(
                    child: Text('OK'),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
                title: Text('Something went wrong'),
              );
            },
            context: context,
          );
        }
      });
    } else {
      model
          .updateProduct(
              _titleTextController.text,
              _descriptionTextController.text,
              _formData['image'],
              double.parse(
                  _priceTextController.text.replaceFirst(RegExp(r','), '.')),
              _formData['location'])
          .then((_) => Navigator.pushReplacementNamed(context, '/products')
              .then((_) => model.selectProduct(null)));
    }
  }

  Widget _buildSubmitButton() {
    return ScopedModelDescendant<MainModel>(
      builder: (BuildContext context, Widget child, MainModel model) {
        return model.isLoading
            ? Center(
                child: AdaptiveProgressIndicator())
            : RaisedButton(
                child: Text('Save'),
                textColor: Colors.white,
                onPressed: () => _submitForm(model),
              );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double deviceWidth = MediaQuery.of(context).size.width;
    final double targetWidth = deviceWidth > 768.0 ? 500.0 : deviceWidth * 0.95;
    final double targetPadding = deviceWidth - targetWidth;

    return ScopedModelDescendant<MainModel>(
      builder: (BuildContext context, Widget child, MainModel model) {
        final Widget pageContent = GestureDetector(
          onTap: () {
            FocusScope.of(context).requestFocus(FocusNode());
          },
          child: Container(
            margin: EdgeInsets.all(10.0),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: targetPadding / 2),
                children: <Widget>[
                  _buildTitleTextField(model.selectedProduct),
                  _buildDescriptionTextField(model.selectedProduct),
                  _buildPriceTextField(model.selectedProduct),
                  SizedBox(height: 10.0),
                  LocationInput(_setLocation, model.selectedProduct),
                  SizedBox(height: 10.0),
                  ImageInput(_setImage, model.selectedProduct),
                  SizedBox(height: 10.0),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        );

        return model.selectedProductIndex == -1
            ? pageContent
            : Scaffold(
                appBar: AppBar(
                  title: Text('Edit Product'),
                ),
                body: pageContent,
              );
      },
    );
  }
}
