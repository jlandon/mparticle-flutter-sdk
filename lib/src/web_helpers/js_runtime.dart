import 'dart:convert';

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Generic Wasm-safe JavaScript interop helpers.
///
/// Only this file and [mparticle_globals.dart] may import
/// `dart:js_interop_unsafe`.

@JS('JSON.stringify')
external JSString _jsonStringify(JSAny? value);

/// Serializes a JS value to a JSON string.
String jsStringify(JSAny? value) => _jsonStringify(value).toDart;

/// Converts a JS value to a Dart object when possible.
Object? jsDartify(JSAny? value) => value?.dartify();

/// Converts a Dart value to a JS interop value.
JSAny? jsifyValue(Object? value) => value?.jsify();

/// JSON round-trip for unknown or dynamic JS object shapes.
Object? stringifyAndDecode(JSAny? value) {
  if (value == null) {
    return null;
  }
  return jsonDecode(jsStringify(value));
}

/// The global JS object (`globalThis` / `window`).
JSObject get globalJsObject => globalContext;

/// Reads a property from the global object.
JSAny? getGlobalProperty(String name) => globalJsObject.getProperty(name.toJS);

/// Calls a method on [object] with variadic JS arguments (supports nulls).
JSAny? callMethodVarArgsOn(
  JSObject object,
  String method,
  List<JSAny?> args,
) =>
    object.callMethodVarArgs(method.toJS, args);

/// Reads a property from a JS object.
JSAny? getProperty(JSObject object, String name) =>
    object.getProperty(name.toJS);

/// Reads a property using bracket notation.
JSAny? getIndex(JSObject object, String key) => object[key];
