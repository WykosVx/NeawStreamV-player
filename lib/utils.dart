
import 'package:flutter/material.dart';

class DeviceHelper {
  static bool isTV(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }
}