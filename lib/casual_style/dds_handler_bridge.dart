import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:pool/pool.dart';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';

typedef _DecodeDdsScaledNative =
    Pointer<Uint8> Function(
      Pointer<Utf16>,
      Int32,
      Int32,
      Pointer<Int32>,
      Pointer<Int32>,
    );
typedef _DecodeDdsScaled =
    Pointer<Uint8> Function(
      Pointer<Utf16>,
      int,
      int,
      Pointer<Int32>,
      Pointer<Int32>,
    );

typedef _FreeNative = Void Function(Pointer<Uint8>);
typedef _Free = void Function(Pointer<Uint8>);

final _dll = DynamicLibrary.open('bcdeclib.dll');

final _decodeDdsScaled = _dll
    .lookupFunction<_DecodeDdsScaledNative, _DecodeDdsScaled>(
      'DecodeDdsScaled',
    );
final _freeBuf = _dll.lookupFunction<_FreeNative, _Free>('FreeDdsBuffer');

({Uint8List pixels, int width, int height})? _decodeDdsIsolate(String path) {
  final pathPtr = path.toNativeUtf16();
  final wPtr = malloc<Int32>();
  final hPtr = malloc<Int32>();

  final result = _decodeDdsScaled(pathPtr, 192, 192, wPtr, hPtr);
  malloc.free(pathPtr);

  if (result == nullptr) {
    malloc.free(wPtr);
    malloc.free(hPtr);
    return null;
  }

  final w = wPtr.value;
  final h = hPtr.value;
  malloc.free(wPtr);
  malloc.free(hPtr);

  final pixels = Uint8List.fromList(result.asTypedList(w * h * 4));
  _freeBuf(result);
  return (pixels: pixels, width: w, height: h);
}

String _cacheKey(String path) {
  final modified = File(path).lastModifiedSync().millisecondsSinceEpoch;
  return '$path@$modified';
}

final _pool = Pool(1);

final _cache = <String, ({Uint8List pixels, int width, int height})>{};

Future<ui.Image?> decodeDdsToImage(String path) async {
  final key = _cacheKey(path);

  final cached = _cache[key];
  if (cached != null) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      cached.pixels,
      cached.width,
      cached.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  return _pool.withResource(() async {
    final alreadyCached = _cache[key];
    if (alreadyCached != null) {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        alreadyCached.pixels,
        alreadyCached.width,
        alreadyCached.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      return completer.future;
    }

    final raw = await compute(_decodeDdsIsolate, path);
    if (raw == null) return null;

    _cache[key] = raw;

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      raw.pixels,
      raw.width,
      raw.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  });
}

void clearDdsCache() {
  _cache.clear();
}
