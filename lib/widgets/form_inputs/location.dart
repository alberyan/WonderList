import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:map_view/map_view.dart';
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as geoloc;

import '../helpers/ensure-visible.dart';
import '../../models/location_data.dart';
import '../../models/product.dart';
import '../../global/global_config.dart';

enum FetchMode { byInput, byGetUserLocation, byFetchFromProduct }

class LocationInput extends StatefulWidget {
  final Function setLocation;
  final Product product;

  LocationInput(this.setLocation, this.product);

  @override
  State<StatefulWidget> createState() {
    return _LocationInputState();
  }
}

class _LocationInputState extends State<LocationInput> {
  final FocusNode _addressInputFocusNode = FocusNode();
  Uri _staticMapUri;
  final TextEditingController _addressInputController = TextEditingController();
  LocationData _locationData;

  @override
  void initState() {
    _addressInputFocusNode.addListener(_updateLocation);
    if (widget.product != null) {
      _getStaticMap(
          widget.product.location.address, FetchMode.byGetUserLocation);
    }
    super.initState();
  }

  @override
  void dispose() {
    _addressInputFocusNode.removeListener(_updateLocation);
    super.dispose();
  }

  Future<String> _getAddress(double lat, double lng) async {
    final Uri uri = Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
      'latlng': '${lat.toString()},${lng.toString()}',
      'key': mapApiKey
    });
    final http.Response response = await http.get(uri);
    final decodedResponse = json.decode(response.body);
    final formattedAddress = decodedResponse['results'][0]['formatted_address'];
    return formattedAddress;
  }

  void _getUserLocation() async {
    final geoloc.Location location = geoloc.Location();
    try {
      final currentLocation = await location.getLocation();
      final address = await _getAddress(
          currentLocation.latitude, currentLocation.longitude);
      _getStaticMap(address, FetchMode.byGetUserLocation,
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude);
    } catch (error) {
      showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Could not fetch location'),
              content: Text('Please add an address manually!'),
              actions: <Widget>[
                FlatButton(
                  child: Text('OK'),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                )
              ],
            );
          });
    }
  }

  void _updateLocation() {
    if (!_addressInputFocusNode.hasFocus) {
      _getStaticMap(_addressInputController.text, FetchMode.byInput);
    }
  }

  void _getStaticMap(String address, FetchMode fetchMode,
      {double latitude, double longitude}) async {
    if (address.isEmpty) {
      setState(() {
        _staticMapUri = null;
      });
      widget.setLocation(null);
      return;
    }
    if (fetchMode == FetchMode.byInput) {
      final Uri uri = Uri.https(
          'maps.googleapis.com', '/maps/api/geocode/json', {
        'address': address,
        'key': mapApiKey
      });
      final http.Response response = await http.get(uri);
      final decodedResponse = json.decode(response.body);
      final formattedAddress =
          decodedResponse['results'][0]['formatted_address'];
      final coords = decodedResponse['results'][0]['geometry']['location'];
      _locationData =
          LocationData(coords['lat'], coords['lng'], formattedAddress);
    } else if (fetchMode == FetchMode.byFetchFromProduct) {
      _locationData = widget.product.location;
    } else {
      _locationData = LocationData(latitude, longitude, address);
    }

    if (mounted) {
      StaticMapProvider provider =
          new StaticMapProvider(mapApiKey);
      final Uri staticMapUri = provider.getStaticUriWithMarkers([
        Marker('position', 'Position', _locationData.latitude,
            _locationData.longitude)
      ],
          center: Location(_locationData.latitude, _locationData.longitude),
          width: 500,
          height: 300,
          maptype: StaticMapViewType.roadmap);
      widget.setLocation(_locationData);

      setState(() {
        _staticMapUri = staticMapUri;
        _addressInputController.text = _locationData.address;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        EnsureVisibleWhenFocused(
          focusNode: _addressInputFocusNode,
          child: TextFormField(
            focusNode: _addressInputFocusNode,
            controller: _addressInputController,
            decoration: InputDecoration(
              labelText: 'Address',
            ),
            validator: (String value) {
              if (_locationData == null || value.isEmpty) {
                return 'No valid location found.';
              }
            },
          ),
        ),
        SizedBox(
          height: 10.0,
        ),
        FlatButton(
          child: Text('Locate User'),
          onPressed: _getUserLocation,
        ),
        SizedBox(
          height: 10.0,
        ),
        _staticMapUri == null
            ? Container()
            : Image.network(_staticMapUri.toString()),
      ],
    );
  }
}
