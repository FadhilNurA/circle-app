import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../config/api_config.dart';

/// Represents a single line of synced lyrics.
class LyricLine {
  final int time; // milliseconds
  final String text;

  LyricLine({required this.time, required this.text});

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      time: (json['time'] as num).toInt(),
      text: json['text'] as String? ?? '',
    );
  }
}

/// Current track information received from the server.
class TrackInfo {
  final String trackId;
  final String trackName;
  final String artistName;
  final String? albumArt;
  final int durationMs;
  final List<LyricLine> lyrics;

  TrackInfo({
    required this.trackId,
    required this.trackName,
    required this.artistName,
    this.albumArt,
    required this.durationMs,
    required this.lyrics,
  });

  factory TrackInfo.fromJson(Map<String, dynamic> json) {
    final lyricsList =
        (json['lyrics'] as List<dynamic>?)
            ?.map((e) => LyricLine.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return TrackInfo(
      trackId: json['trackId'] as String? ?? '',
      trackName: json['trackName'] as String? ?? 'Unknown',
      artistName: json['artistName'] as String? ?? 'Unknown',
      albumArt: json['albumArt'] as String?,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      lyrics: lyricsList,
    );
  }
}

/// Playback progress update from the server.
class PlaybackUpdate {
  final bool isPlaying;
  final int progressMs;
  final int timestamp;

  PlaybackUpdate({
    required this.isPlaying,
    required this.progressMs,
    required this.timestamp,
  });

  factory PlaybackUpdate.fromJson(Map<String, dynamic> json) {
    return PlaybackUpdate(
      isPlaying: json['isPlaying'] as bool? ?? false,
      progressMs: (json['progressMs'] as num?)?.toInt() ?? 0,
      timestamp:
          (json['timestamp'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// Manages the Socket.IO connection to the lyrics room server.
class SocketService {
  static SocketService? _instance;
  io.Socket? _socket;

  // Stream controllers for events
  final _trackChangedController = StreamController<TrackInfo>.broadcast();
  final _playbackUpdateController =
      StreamController<PlaybackUpdate>.broadcast();
  final _roomCreatedController = StreamController<String>.broadcast();
  final _roomJoinedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _roomClosedController = StreamController<String>.broadcast();
  final _memberCountController = StreamController<int>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Public streams
  Stream<TrackInfo> get onTrackChanged => _trackChangedController.stream;
  Stream<PlaybackUpdate> get onPlaybackUpdate =>
      _playbackUpdateController.stream;
  Stream<String> get onRoomCreated => _roomCreatedController.stream;
  Stream<Map<String, dynamic>> get onRoomJoined => _roomJoinedController.stream;
  Stream<String> get onRoomClosed => _roomClosedController.stream;
  Stream<int> get onMemberCount => _memberCountController.stream;
  Stream<String> get onError => _errorController.stream;
  Stream<bool> get onConnectionChanged => _connectionController.stream;

  bool get isConnected => _socket?.connected ?? false;
  String? currentRoomId;

  SocketService._();

  factory SocketService() {
    _instance ??= SocketService._();
    return _instance!;
  }

  /// Connect to the Socket.IO server.
  void connect() {
    if (_socket != null && _socket!.connected) return;

    _socket = io.io(
      ApiConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .build(),
    );

    _setupListeners();
    _socket!.connect();
  }

  void _setupListeners() {
    final socket = _socket!;

    socket.onConnect((_) {
      print('[Socket] Connected');
      _connectionController.add(true);
    });

    socket.onDisconnect((_) {
      print('[Socket] Disconnected');
      _connectionController.add(false);
    });

    socket.onConnectError((error) {
      print('[Socket] Connection error: $error');
      _errorController.add('Gagal terhubung ke server');
      _connectionController.add(false);
    });

    // ─── Room Events ───
    socket.on('room_created', (data) {
      final roomId = data['roomId'] as String;
      currentRoomId = roomId;
      _roomCreatedController.add(roomId);
    });

    socket.on('room_joined', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      currentRoomId = map['roomId'] as String?;

      // If there are existing lyrics, emit as a track change
      if (map['lyrics'] != null && map['currentTrackId'] != null) {
        _trackChangedController.add(
          TrackInfo(
            trackId: map['currentTrackId'] as String,
            trackName: '',
            artistName: '',
            durationMs: 0,
            lyrics: (map['lyrics'] as List<dynamic>)
                .map(
                  (e) =>
                      LyricLine.fromJson(Map<String, dynamic>.from(e as Map)),
                )
                .toList(),
          ),
        );
      }

      _roomJoinedController.add(map);
    });

    socket.on('room_closed', (data) {
      final message = data['message'] as String? ?? 'Room ditutup';
      currentRoomId = null;
      _roomClosedController.add(message);
    });

    socket.on('member_count', (data) {
      final count = (data['count'] as num).toInt();
      _memberCountController.add(count);
    });

    socket.on('error_event', (data) {
      final message = data['message'] as String? ?? 'Terjadi kesalahan';
      _errorController.add(message);
    });

    // ─── Playback Events ───
    socket.on('track_changed', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _trackChangedController.add(TrackInfo.fromJson(map));
    });

    socket.on('playback_update', (data) {
      final map = Map<String, dynamic>.from(data as Map);
      _playbackUpdateController.add(PlaybackUpdate.fromJson(map));
    });
  }

  /// Create a new lyrics room (host).
  void createRoom({required String spotifyToken, required String userId}) {
    _socket?.emit('create_room', {
      'spotifyToken': spotifyToken,
      'userId': userId,
    });
  }

  /// Join an existing lyrics room (listener).
  void joinRoom({required String roomId}) {
    _socket?.emit('join_room', {'roomId': roomId});
  }

  /// Leave the current room.
  void leaveRoom() {
    if (currentRoomId != null) {
      _socket?.emit('leave_room', {'roomId': currentRoomId});
      currentRoomId = null;
    }
  }

  /// Disconnect from the server entirely.
  void disconnect() {
    leaveRoom();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Dispose all stream controllers.
  void dispose() {
    disconnect();
    _trackChangedController.close();
    _playbackUpdateController.close();
    _roomCreatedController.close();
    _roomJoinedController.close();
    _roomClosedController.close();
    _memberCountController.close();
    _errorController.close();
    _connectionController.close();
    _instance = null;
  }
}
