class JsObject {
  JsObject(dynamic constructor, [List? arguments]);
  factory JsObject.jsify(dynamic object) => JsObject(null);
  
  dynamic operator [](dynamic key) => null;
  void operator []=(dynamic key, dynamic value) {}
  dynamic callMethod(String method, [List? args]) => null;
}

dynamic get context => null;

Function allowInterop(Function f) => f;
