import 'package:flutter/material.dart';

class AddressTag extends StatelessWidget{
  final String address;

  AddressTag(this.address);

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.5),
              child:Text(address),
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(6.0),
            ),
          );
  }
}