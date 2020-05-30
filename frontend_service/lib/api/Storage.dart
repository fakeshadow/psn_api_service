import 'package:localstorage/localstorage.dart';

class Storage {

  final LocalStorage storage;

  Storage(this.storage);

  static init() {
    final LocalStorage storage = new LocalStorage('PSN_API_SERVICE_DEMO');

    return Storage(storage);
  }

  Future<void> setInstant() async {
    final ready = await this.storage.ready.timeout(Duration(seconds: 3));
    if (ready) {
      final now = DateTime.now().toString();
      this.storage.setItem("instant", now);
    } else {
      throw ("Can't write to local storage");
    }
  }

  Future<String> getInstant() async {
    final ready = await this.storage.ready.timeout(Duration(seconds: 3));
    if (ready) {
      return this.storage.getItem("instant");
    } else {
      throw ("Can't read from local storage");
    }
  }
}