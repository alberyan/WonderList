import 'package:flutter/material.dart';
import 'dart:async';

import 'package:map_view/map_view.dart';

import '../widgets/ui_element/title_default.dart';
import '../models/product.dart';
import '../widgets/products/product_fab.dart';

class ProductPage extends StatelessWidget {
  final Product product;

  ProductPage(this.product);

  void _showMap() {
    final List<Marker> markers = <Marker>[
      Marker('position', 'Position', product.location.latitude,
          product.location.longitude)
    ];
    final CameraPosition cameraPosition = CameraPosition(
        Location(product.location.latitude, product.location.longitude), 14.0);
    final mapView = MapView();
    mapView.show(
      MapOptions(
          initialCameraPosition: cameraPosition,
          mapViewType: MapViewType.normal,
          title: 'Product Location'),
      toolbarActions: [ToolbarAction('Close', 1)],
    );
    mapView.onToolbarAction.listen((int id) {
      if (id == 1) {
        mapView.dismiss();
      }
    });
    mapView.onMapReady.listen((_) {
      mapView.setMarkers(markers);
    });
  }

  Widget _buildAddressPriceRow(Product product) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          onTap: _showMap,
          child: Text(
            product.location.address,
            style: TextStyle(color: Colors.grey),
          ),
        ),
        Container(
          margin: EdgeInsets.symmetric(horizontal: 5.0),
          child: Text(
            '|',
            style: TextStyle(color: Colors.grey),
          ),
        ),
        Text(
          '\$${product.price.toString()}',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () {
        Navigator.pop(context, false);
        return Future.value(false);
      },
      child: Scaffold(
        // appBar: AppBar(
        //   title: Text('Product Detail - ' + product.title),
        // ),
        body: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
                expandedHeight: 256.0,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(product.title),
                  background: Hero(
                    tag: product.id,
                    child: FadeInImage(
                      image: NetworkImage(product.imageUrl),
                      height: 300.0,
                      fit: BoxFit.cover,
                      placeholder: AssetImage('assets/food.jpg'),
                    ),
                  ),
                )),
            SliverList(
              delegate: SliverChildListDelegate([
                Container(
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(10.0),
                  child: TitleDefault(product.title),
                ),
                _buildAddressPriceRow(product),
                Container(
                  padding: EdgeInsets.all(10.0),
                  child: Text(
                    product.description,
                    textAlign: TextAlign.center,
                  ),
                ),
              ]),
            )
          ],
        ),

        floatingActionButton: ProductFab(product),
      ),
    );
  }
}
