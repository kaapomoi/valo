import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

enum LightingMode { off, solid, sparkle }

class Light {
  final String ip;
  late String name;
  late LightingMode lightingMode;
  late Color color;
  bool active = true;

  Light(this.ip) {
    lightingMode = LightingMode.solid;
    name = ip;
    color = Colors.white;
  }

  Future<http.Response> toggleOnOff() async {
    final Uri ur = Uri.http(ip, "/api/v1/basic");
    if (lightingMode != LightingMode.off) {
      lightingMode = LightingMode.off;
      return http.post(ur, body: "{ 'mode': 0 }");
    } else {
      lightingMode = LightingMode.solid;
      return http.post(ur, body: "{ 'mode': 1 }");
    }
  }

  Future<http.Response> turnOff() async {
    lightingMode = LightingMode.off;
    return http.post(Uri.http(ip, "/api/v1/basic"), body: "{ 'mode': 0 }");
  }

  Future<http.Response> post(String api, String body) async {
    return http.post(Uri.http(ip, active ? api : ""), body: body);
  }

  void toggleActive() {
    active = !active;
  }

  bool isActive() {
    return active;
  }

  void setColorIfActive(Color newColor) {
    if (active) {
      color = newColor;
    }
  }

  String id() {
    if (name.isNotEmpty) {
      return name;
    }

    RegExp reg = RegExp(r"\d{1,3}$");
    int ind = ip.lastIndexOf(reg);
    return ip.substring(ind - 2, ip.length);
  }
}
