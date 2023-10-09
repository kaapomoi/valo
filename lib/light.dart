import 'package:http/http.dart' as http;

class Light {
  final String ip;
  bool active = true;

  Light(this.ip);

  Future<http.Response> post(String api, String body) async {
    final Uri ur = Uri.http(ip, active ? api : "");
    return http.post(ur, body: body);
  }

  void toggleActive() {
    active = !active;
  }

  bool isActive() {
    return active;
  }

  String id() {
    RegExp reg = RegExp(r"\d{1,3}$");
    int ind = ip.lastIndexOf(reg);
    return ip.substring(ind - 2, ip.length);
  }
}
