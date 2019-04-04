import 'package:flutter/material.dart';
import '../../models/product.dart';

import 'package:scoped_model/scoped_model.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../scoped_models/main.dart';

class ProductFab extends StatefulWidget {
  final Product product;

  ProductFab(this.product);

  @override
  State<StatefulWidget> createState() {
    return _ProductFabState();
  }
}

class _ProductFabState extends State<ProductFab> with TickerProviderStateMixin {
  AnimationController _animationController;

  @override
  void initState() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ScopedModelDescendant<MainModel>(
      builder: (BuildContext context, Widget child, MainModel model) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 70.0,
              width: 56.0,
              alignment: FractionalOffset.topCenter,
              child: ScaleTransition(
                scale: CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(0.0, 1.0, curve: Curves.easeOut)),
                child: FloatingActionButton(
                  heroTag: 'contact',
                  backgroundColor: Theme.of(context).cardColor,
                  mini: true,
                  onPressed: () async {
                    final url = 'mailto:${widget.product.userEmail}';
                    if (await canLaunch(url)) {
                      await launch(url);
                    } else {
                      throw 'Could not launch';
                    }
                  },
                  child: Icon(
                    Icons.mail_outline,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),
            Container(
              height: 70.0,
              width: 56.0,
              alignment: FractionalOffset.topCenter,
              child: ScaleTransition(
                scale: CurvedAnimation(
                    parent: _animationController,
                    curve: Interval(0.0, 1.0, curve: Curves.easeOut)),
                child: FloatingActionButton(
                  heroTag: 'favorite',
                  backgroundColor: Theme.of(context).cardColor,
                  mini: true,
                  onPressed: () {
                    setState(() {
                      model.toggleProductFavoriteStatus();
                    });
                  },
                  child: Icon(
                    model.selectedProduct.isFavorite
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
            Container(
                height: 70.0,
                width: 56.0,
                child: RotationTransition(
                  child: FloatingActionButton(
                    heroTag: 'more',
                    onPressed: () {
                      if (_animationController.isDismissed) {
                        _animationController.forward();
                      } else {
                        _animationController.reverse();
                      }
                    },
                    child: Icon(Icons.more_horiz),
                  ),
                  turns: Tween(begin: 0.0, end: 0.25)
                      .animate(_animationController),
                )),
          ],
        );
      },
    );
  }
}
