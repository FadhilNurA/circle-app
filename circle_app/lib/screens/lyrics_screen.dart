import 'dart:async';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/socket_service.dart';

class LyricsScreen extends StatefulWidget {
  final String roomId;
  final bool isHost;

  const LyricsScreen({super.key, required this.roomId, this.isHost = false});

  @override
  State<LyricsScreen> createState() => _LyricsScreenState();
}

class _LyricsScreenState extends State<LyricsScreen>
    with SingleTickerProviderStateMixin {
  final SocketService _socketService = SocketService();
  final ScrollController _scrollController = ScrollController();

  TrackInfo? _currentTrack;
  int _progressMs = 0;
  bool _isPlaying = false;
  int _memberCount = 1;
  int _syncOffsetMs = 0;
  int _activeLyricIndex = -1;

  Timer? _progressTimer;
  int _lastServerProgressMs = 0;
  int _lastServerTimestamp = 0;

  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
    _startProgressInterpolation();
  }

  void _setupListeners() {
    _subscriptions.add(
      _socketService.onTrackChanged.listen((track) {
        setState(() {
          _currentTrack = track;
          _activeLyricIndex = -1;
        });
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }),
    );
    _subscriptions.add(
      _socketService.onPlaybackUpdate.listen((update) {
        _lastServerProgressMs = update.progressMs;
        _lastServerTimestamp = update.timestamp;
        setState(() {
          _isPlaying = update.isPlaying;
          _progressMs = update.progressMs;
        });
      }),
    );
    _subscriptions.add(
      _socketService.onMemberCount.listen(
        (count) => setState(() => _memberCount = count),
      ),
    );
    _subscriptions.add(
      _socketService.onRoomClosed.listen((message) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: AppColors.error),
          );
          Navigator.of(context).pop();
        }
      }),
    );
    _subscriptions.add(
      _socketService.onError.listen((error) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppColors.error),
          );
      }),
    );
  }

  void _startProgressInterpolation() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_isPlaying || _currentTrack == null) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      final interpolated =
          _lastServerProgressMs + (now - _lastServerTimestamp) + _syncOffsetMs;
      setState(() {
        _progressMs = interpolated;
        _updateActiveLyric();
      });
    });
  }

  void _updateActiveLyric() {
    if (_currentTrack == null || _currentTrack!.lyrics.isEmpty) return;
    final lyrics = _currentTrack!.lyrics;
    int newIndex = -1;
    for (int i = lyrics.length - 1; i >= 0; i--) {
      if (_progressMs >= lyrics[i].time) {
        newIndex = i;
        break;
      }
    }
    if (newIndex != _activeLyricIndex && newIndex >= 0) {
      _activeLyricIndex = newIndex;
      _scrollToActiveLyric();
    }
  }

  void _scrollToActiveLyric() {
    if (!_scrollController.hasClients || _activeLyricIndex < 0) return;
    final targetOffset = (_activeLyricIndex * 64.0) - 200.0;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    for (final sub in _subscriptions) sub.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            _socketService.leaveRoom();
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Room ${widget.roomId}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              '$_memberCount ${_memberCount == 1 ? 'listener' : 'listeners'}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.remove_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
            onPressed: () {
              setState(() => _syncOffsetMs -= 500);
              _showOffsetSnackbar();
            },
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_syncOffsetMs >= 0 ? '+' : ''}${_syncOffsetMs}ms',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.add_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
            onPressed: () {
              setState(() => _syncOffsetMs += 500);
              _showOffsetSnackbar();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTrackHeader(),
          _buildProgressBar(),
          const SizedBox(height: 8),
          Expanded(child: _buildLyricsView()),
        ],
      ),
    );
  }

  Widget _buildTrackHeader() {
    if (_currentTrack == null) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.music_note_rounded,
                size: 48,
                color: AppColors.primary.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Menunggu host memutar lagu...',
              style: TextStyle(color: AppColors.textMuted, fontSize: 15),
            ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _currentTrack!.albumArt != null
                ? Image.network(
                    _currentTrack!.albumArt!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _albumArtPlaceholder(),
                  )
                : _albumArtPlaceholder(),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentTrack!.trackName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _currentTrack!.artistName,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (_isPlaying)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (i) => AnimatedContainer(
                  duration: Duration(milliseconds: 300 + i * 100),
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  width: 3,
                  height: 12.0 + (i % 2 == 0 ? 8 : 4),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            )
          else
            Icon(
              Icons.pause_circle_filled_rounded,
              color: AppColors.textMuted.withOpacity(0.5),
              size: 28,
            ),
        ],
      ),
    );
  }

  Widget _albumArtPlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.album_rounded,
        color: AppColors.textMuted,
        size: 28,
      ),
    );
  }

  Widget _buildProgressBar() {
    final duration = _currentTrack?.durationMs ?? 1;
    final progress = (_progressMs / duration).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.surfaceLight,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_progressMs),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              Text(
                _formatDuration(duration),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLyricsView() {
    if (_currentTrack == null || _currentTrack!.lyrics.isEmpty) {
      return const Center(
        child: Text(
          '♪ Menunggu lirik... ♪',
          style: TextStyle(color: AppColors.textMuted, fontSize: 18),
        ),
      );
    }
    final lyrics = _currentTrack!.lyrics;
    return ShaderMask(
      shaderCallback: (Rect bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white,
          Colors.white,
          Colors.transparent,
        ],
        stops: [0.0, 0.08, 0.92, 1.0],
      ).createShader(bounds),
      blendMode: BlendMode.dstIn,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        itemCount: lyrics.length,
        itemBuilder: (context, index) {
          final isActive = index == _activeLyricIndex;
          final isPast = index < _activeLyricIndex;
          return GestureDetector(
            onTap: () {
              setState(() => _activeLyricIndex = index);
              _scrollToActiveLyric();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                vertical: isActive ? 12 : 8,
                horizontal: 4,
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: TextStyle(
                  fontSize: isActive ? 24 : 18,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w400,
                  color: isActive
                      ? AppColors.textPrimary
                      : isPast
                      ? AppColors.textMuted.withOpacity(0.5)
                      : AppColors.textSecondary,
                  height: 1.4,
                ),
                child: Text(lyrics[index].text),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(int ms) {
    final totalSeconds = (ms / 1000).floor();
    final minutes = (totalSeconds / 60).floor();
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showOffsetSnackbar() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Offset: ${_syncOffsetMs >= 0 ? '+' : ''}${_syncOffsetMs}ms',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
