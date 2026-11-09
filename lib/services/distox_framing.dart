import 'dart:typed_data';

import 'distox_protocol.dart';

/// How DistoX2 packets and commands travel over one kind of Bluetooth link.
///
/// The rest of the app speaks the DistoX2 protocol (InsideDistoX2.txt): 8-byte
/// packets in, one-byte acknowledgements and the DistoX2 commands out. A
/// framing turns received bytes into those packets and DistoX2 commands into
/// the bytes the device expects.
abstract class DistoXFraming {
  /// The DistoX2 packets in [data], as far as they are complete
  List<Uint8List> receive(Uint8List data);

  /// Bytes acknowledging [packet], or null if it needs none
  Uint8List? acknowledge(Uint8List packet);

  /// Bytes sending the DistoX2 [command]
  Uint8List encode(Uint8List command);

  /// Drop what is left of an earlier connection
  void reset();
}

/// The DistoX2 over Bluetooth Classic SPP: a byte stream of 8-byte packets,
/// each but memory replies acknowledged, and commands sent as they are.
class ClassicFraming implements DistoXFraming {
  final List<int> _buffer = [];

  @override
  List<Uint8List> receive(Uint8List data) {
    _buffer.addAll(data);
    final packets = <Uint8List>[];
    while (_buffer.length >= 8) {
      packets.add(Uint8List.fromList(_buffer.sublist(0, 8)));
      _buffer.removeRange(0, 8);
    }
    return packets;
  }

  @override
  Uint8List? acknowledge(Uint8List packet) {
    if ((packet[0] & 0x3F) == DistoXPacketType.memoryReply) return null;
    return _acknowledgement(packet);
  }

  @override
  Uint8List encode(Uint8List command) => command;

  @override
  void reset() => _buffer.clear();
}

/// The DistoX BLE (`docs/distox6/Disto xble comm protocol.pdf`), which wraps
/// the DistoX2 protocol for Bluetooth Low Energy.
///
/// Each notification is one packet: a shot or calibration shot joins the two
/// DistoX2 packets behind a byte telling which it is, and is acknowledged
/// once; a memory reply carries the bytes read. Commands are wrapped in
/// `data:`, their length and a line break.
class BleFraming implements DistoXFraming {
  static const int _shot = 0x01;
  static const int _calibrationShot = 0x02;
  static const int _readMemory = 0x3d;
  static const int _writeMemory = 0x3e;

  @override
  List<Uint8List> receive(Uint8List data) {
    if (data.isEmpty) return const [];
    switch (data[0]) {
      case _shot || _calibrationShot when data.length >= 17:
        return [
          Uint8List.sublistView(data, 1, 9),
          Uint8List.sublistView(data, 9, 17),
        ];
      // The reply to reads and writes alike; the app reads and writes four
      // bytes at a time, as the DistoX2 does
      case _readMemory || _writeMemory when data.length >= 7:
        return [
          Uint8List.fromList([
            DistoXPacketType.memoryReply,
            ...data.sublist(1, 7),
            0,
          ]),
        ];
    }
    return const [];
  }

  @override
  Uint8List? acknowledge(Uint8List packet) {
    // The first packet of a shot or calibration shot stands for both
    final type = packet[0] & 0x3F;
    if (type != DistoXPacketType.measurement &&
        type != DistoXPacketType.calibrationAccel) {
      return null;
    }
    return _wrap(_acknowledgement(packet));
  }

  @override
  Uint8List encode(Uint8List command) {
    switch (command[0]) {
      case DistoXCommand.readMemory when command.length == 3:
        return _wrap([_readMemory, command[1], command[2], 4]);
      case DistoXCommand.writeMemory when command.length == 7:
        return _wrap([_writeMemory, command[1], command[2], 4, ...command.sublist(3)]);
    }
    return _wrap(command);
  }

  @override
  void reset() {}

  static Uint8List _wrap(List<int> payload) => Uint8List.fromList([
        ...'data:'.codeUnits,
        payload.length,
        ...payload,
        0x0d,
        0x0a,
      ]);
}

/// The DistoX2 acknowledgement: the packet's sequence bit and 0x55
Uint8List _acknowledgement(Uint8List packet) =>
    Uint8List.fromList([(packet[0] & 0x80) | 0x55]);
