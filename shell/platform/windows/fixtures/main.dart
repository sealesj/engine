// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data' show ByteData, Endian, Uint8List;
import 'dart:ui' as ui;
import 'dart:convert';

// Signals a waiting latch in the native test.
@pragma('vm:external-name', 'Signal')
external void signal();

// Signals a waiting latch in the native test, passing a boolean value.
@pragma('vm:external-name', 'SignalBoolValue')
external void signalBoolValue(bool value);

// Signals a waiting latch in the native test, passing a string value.
@pragma('vm:external-name', 'SignalStringValue')
external void signalStringValue(String value);

// Signals a waiting latch in the native test, which returns a value to the fixture.
@pragma('vm:external-name', 'SignalBoolReturn')
external bool signalBoolReturn();

// Notify the native test that the first frame has been scheduled.
@pragma('vm:external-name', 'NotifyFirstFrameScheduled')
external void notifyFirstFrameScheduled();

void main() {}

@pragma('vm:entry-point')
void hiPlatformChannels() {
  ui.channelBuffers.setListener('hi',
      (ByteData? data, ui.PlatformMessageResponseCallback callback) async {
    ui.PlatformDispatcher.instance.sendPlatformMessage('hi', data,
        (ByteData? reply) {
      ui.PlatformDispatcher.instance
          .sendPlatformMessage('hi', reply, (ByteData? reply) {});
    });
    callback(data);
  });
}

/// Returns a future that completes when
/// `PlatformDispatcher.instance.onSemanticsEnabledChanged` fires.
Future<void> get semanticsChanged {
  final Completer<void> semanticsChanged = Completer<void>();
  ui.PlatformDispatcher.instance.onSemanticsEnabledChanged =
      semanticsChanged.complete;
  return semanticsChanged.future;
}

@pragma('vm:entry-point')
void sendAccessibilityAnnouncement() async {
  // Wait until semantics are enabled.
  if (!ui.PlatformDispatcher.instance.semanticsEnabled) {
    await semanticsChanged;
  }

  // Serializers for data types are in the framework, so this will be hardcoded.
  const int valueMap = 13, valueString = 7;
  // Corresponds to:
  // Map<String, Object> data =
  // {"type": "announce", "data": {"message": ""}};
  final Uint8List data = Uint8List.fromList([
    valueMap, // _valueMap
    2, // Size
    // key: "type"
    valueString,
    'type'.length,
    ...'type'.codeUnits,
    // value: "announce"
    valueString,
    'announce'.length,
    ...'announce'.codeUnits,
    // key: "data"
    valueString,
    'data'.length,
    ...'data'.codeUnits,
    // value: map
    valueMap, // _valueMap
    1, // Size
    // key: "message"
    valueString,
    'message'.length,
    ...'message'.codeUnits,
    // value: ""
    valueString,
    0, // Length of empty string == 0.
  ]);
  final ByteData byteData = data.buffer.asByteData();

  ui.PlatformDispatcher.instance.sendPlatformMessage(
    'flutter/accessibility',
    byteData,
    (ByteData? _) => signal(),
  );
}

@pragma('vm:entry-point')
void exitTestExit() async {
  final Completer<ByteData?> closed = Completer<ByteData?>();
  ui.channelBuffers.setListener('flutter/platform', (ByteData? data, ui.PlatformMessageResponseCallback callback) async {
    final String jsonString = json.encode(<Map<String, String>>[{'response': 'exit'}]);
    final ByteData responseData = ByteData.sublistView(utf8.encode(jsonString));
    callback(responseData);
    closed.complete(data);
  });
  await closed.future;
}

@pragma('vm:entry-point')
void exitTestCancel() async {
  final Completer<ByteData?> closed = Completer<ByteData?>();
  ui.channelBuffers.setListener('flutter/platform', (ByteData? data, ui.PlatformMessageResponseCallback callback) async {
    final String jsonString = json.encode(<Map<String, String>>[{'response': 'cancel'}]);
    final ByteData responseData = ByteData.sublistView(utf8.encode(jsonString));
    callback(responseData);
    closed.complete(data);
  });
  await closed.future;

  // Because the request was canceled, the below shall execute.
  final Completer<ByteData?> exited = Completer<ByteData?>();
  final String jsonString = json.encode(<String, dynamic>{
    'method': 'System.exitApplication',
    'args': <String, dynamic>{
      'type': 'required', 'exitCode': 0
      }
    });
  ui.PlatformDispatcher.instance.sendPlatformMessage(
    'flutter/platform',
    ByteData.sublistView(utf8.encode(jsonString)),
    (ByteData? reply) {
      exited.complete(reply);
    });
  await exited.future;
}

@pragma('vm:entry-point')
void enableLifecycleTest() async {
  final Completer<ByteData?> finished = Completer<ByteData?>();
  ui.channelBuffers.setListener('flutter/lifecycle', (ByteData? data, ui.PlatformMessageResponseCallback callback) async {
    if (data != null) {
      ui.PlatformDispatcher.instance.sendPlatformMessage(
        'flutter/unittest',
        data,
        (ByteData? reply) {
          finished.complete();
        });
    }
  });
  await finished.future;
}

@pragma('vm:entry-point')
void enableLifecycleToFrom() async {
  ui.channelBuffers.setListener('flutter/lifecycle', (ByteData? data, ui.PlatformMessageResponseCallback callback) async {
    if (data != null) {
      ui.PlatformDispatcher.instance.sendPlatformMessage(
        'flutter/unittest',
        data,
        (ByteData? reply) {});
    }
  });
  final Completer<ByteData?> enabledLifecycle = Completer<ByteData?>();
  ui.PlatformDispatcher.instance.sendPlatformMessage('flutter/platform', ByteData.sublistView(utf8.encode('{"method":"System.initializationComplete"}')), (ByteData? data) {
    enabledLifecycle.complete(data);
  });
}

@pragma('vm:entry-point')
void sendCreatePlatformViewMethod() async {
  // The platform view method channel uses the standard method codec.
  // See https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/services/message_codecs.dart#L262
  // for the implementation of the encoding and magic number identifiers.
  const int valueString = 7;
  const int valueMap = 13;
  const int valueInt32 = 3;
  const String method = 'create';
  const String typeKey = 'viewType';
  const String typeValue = 'type';
  const String idKey = 'id';
  final List<int> data = <int>[
    // Method name
    valueString, method.length, ...utf8.encode(method),
    // Method arguments: {'type': 'type':, 'id': 0}
    valueMap, 2,
    valueString, typeKey.length, ...utf8.encode(typeKey),
    valueString, typeValue.length, ...utf8.encode(typeValue),
    valueString, idKey.length, ...utf8.encode(idKey),
    valueInt32, 0, 0, 0, 0,
  ];

  final Completer<ByteData?> completed = Completer<ByteData?>();
  final ByteData bytes = ByteData.sublistView(Uint8List.fromList(data));
  ui.PlatformDispatcher.instance.sendPlatformMessage('flutter/platform_views', bytes, (ByteData? response) {
    completed.complete(response);
  });
  await completed.future;
}

@pragma('vm:entry-point')
void customEntrypoint() {}

@pragma('vm:entry-point')
void verifyNativeFunction() {
  signal();
}

@pragma('vm:entry-point')
void verifyNativeFunctionWithParameters() {
  signalBoolValue(true);
}

@pragma('vm:entry-point')
void verifyNativeFunctionWithReturn() {
  bool value = signalBoolReturn();
  signalBoolValue(value);
}

@pragma('vm:entry-point')
void readPlatformExecutable() {
  signalStringValue(io.Platform.executable);
}

@pragma('vm:entry-point')
void drawHelloWorld() {
  ui.PlatformDispatcher.instance.onBeginFrame = (Duration duration) {
    final ui.ParagraphBuilder paragraphBuilder =
        ui.ParagraphBuilder(ui.ParagraphStyle())..addText('Hello world');
    final ui.Paragraph paragraph = paragraphBuilder.build();

    paragraph.layout(const ui.ParagraphConstraints(width: 800.0));

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    canvas.drawParagraph(paragraph, ui.Offset.zero);

    final ui.Picture picture = recorder.endRecording();
    final ui.SceneBuilder sceneBuilder = ui.SceneBuilder()
      ..addPicture(ui.Offset.zero, picture)
      ..pop();

    ui.window.render(sceneBuilder.build());
  };

  ui.PlatformDispatcher.instance.scheduleFrame();
  notifyFirstFrameScheduled();
}
