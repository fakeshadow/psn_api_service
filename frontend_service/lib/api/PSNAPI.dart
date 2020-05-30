import 'dart:convert' as convert;

import 'package:http/http.dart' as http;

class PSNAPI {
  final String url;

  const PSNAPI({this.url});

  Future<Map<String, dynamic>> getProfile(String onlineId) async {
    final url = _profileUrl(onlineId);
    return this.get(url);
  }

  Future<Map<String, dynamic>> getTitles(String onlineId, String offset) async {
    final url = _titlesUrl(onlineId, offset);
    return this.get(url);
  }

  Future<Map<String, dynamic>> getSet(String onlineId, String npId) async {
    final url = _setUrl(onlineId, npId);
    return this.get(url);
  }

  Future<Map<String, dynamic>> getStore(
      String lang, String region, String age, String name) async {
    final url = _storeUrl(lang, region, age, name);
    return this.get(url);
  }

  String _profileUrl(String onlineId) {
    return '${this.url}?query_type=Profile&online_id=$onlineId';
  }

  String _titlesUrl(String onlineId, String offset) {
    return '${this.url}?query_type=Titles&online_id=$onlineId&offset=$offset';
  }

  String _setUrl(String onlineId, String npId) {
    return '${this.url}?query_type=TrophySet&online_id=$onlineId&np_communication_id=$npId';
  }

  String _storeUrl(String lang, String region, String age, String name) {
    final _name = name.replaceAll(' ', '%20');

    return '${this.url}?query_type=Store&language=$lang&region=$region&age=$age&name=$_name';
  }

  Future<Map<String, dynamic>> get(String url) async {
    final res = await http.get(url);

    final json = convert.jsonDecode(res.body);
    if (json['status'] != 200) {
      throw json['error'];
    }
    return json['psn_data'];
  }
}
