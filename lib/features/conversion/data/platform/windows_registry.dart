import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// Leitura mínima do registro do Windows.
abstract interface class RegistryReader {
  /// A chave existe em HKEY_CLASSES_ROOT?
  bool classesRootKeyExists(String subKey);

  /// Valor padrão (texto) de uma chave em HKEY_LOCAL_MACHINE, nas visões de
  /// 64 e 32 bits.
  String? localMachineDefaultValue(String subKey);
}

class Win32RegistryReader implements RegistryReader {
  const Win32RegistryReader();

  @override
  bool classesRootKeyExists(String subKey) {
    final key = subKey.toNativeUtf16();
    final handle = calloc<HKEY>();
    try {
      final status =
          RegOpenKeyEx(HKEY_CLASSES_ROOT, key, 0, KEY_READ, handle);
      if (status != ERROR_SUCCESS) return false;
      RegCloseKey(handle.value);
      return true;
    } finally {
      calloc
        ..free(key)
        ..free(handle);
    }
  }

  @override
  String? localMachineDefaultValue(String subKey) {
    for (final view in const [RRF_SUBKEY_WOW6464KEY, RRF_SUBKEY_WOW6432KEY]) {
      final value = _readString(subKey, view);
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String? _readString(String subKey, int viewFlag) {
    final key = subKey.toNativeUtf16();
    final size = calloc<DWORD>();
    try {
      final flags = RRF_RT_REG_SZ | viewFlag;
      var status = RegGetValue(
        HKEY_LOCAL_MACHINE,
        key,
        nullptr,
        flags,
        nullptr,
        nullptr,
        size,
      );
      if (status != ERROR_SUCCESS || size.value == 0) return null;
      final buffer = calloc<Uint8>(size.value);
      try {
        status = RegGetValue(
          HKEY_LOCAL_MACHINE,
          key,
          nullptr,
          flags,
          nullptr,
          buffer.cast(),
          size,
        );
        if (status != ERROR_SUCCESS) return null;
        return buffer.cast<Utf16>().toDartString();
      } finally {
        calloc.free(buffer);
      }
    } finally {
      calloc
        ..free(key)
        ..free(size);
    }
  }
}
