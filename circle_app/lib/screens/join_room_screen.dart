import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';
import '../services/socket_service.dart';
import '../services/storage_service.dart';
import 'lyrics_screen.dart';

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});

  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final SocketService _socketService = SocketService();
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _spotifyTokenController = TextEditingController();
  bool _isConnecting = false;
  bool _isConnected = false;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _subscriptions.add(
      _socketService.onRoomCreated.listen((roomId) {
        if (mounted)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => LyricsScreen(roomId: roomId, isHost: true),
            ),
          );
      }),
    );
    _subscriptions.add(
      _socketService.onRoomJoined.listen((data) {
        final roomId = data['roomId']?.toString() ?? '';
        if (mounted && roomId.isNotEmpty)
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LyricsScreen(roomId: roomId)),
          );
      }),
    );
    _subscriptions.add(
      _socketService.onError.listen((error) {
        if (mounted) {
          setState(() => _isConnecting = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error), backgroundColor: AppColors.error),
          );
        }
      }),
    );
    _subscriptions.add(
      _socketService.onConnectionChanged.listen((connected) {
        if (mounted) setState(() => _isConnected = connected);
      }),
    );
  }

  @override
  void dispose() {
    _roomIdController.dispose();
    _spotifyTokenController.dispose();
    for (final sub in _subscriptions) sub.cancel();
    super.dispose();
  }

  void _connectSocket() {
    setState(() {
      _isConnecting = true;
    });
    _socketService.connect();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isConnecting = false);
    });
  }

  void _createRoom() async {
    final token = _spotifyTokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan Spotify Access Token'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final user = await StorageService.getUser();
    _socketService.createRoom(
      spotifyToken: token,
      userId: user?.id ?? 'unknown',
    );
  }

  void _joinRoom() {
    final roomId = _roomIdController.text.trim().toUpperCase();
    if (roomId.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Room ID harus 6 karakter'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    _socketService.joinRoom(roomId: roomId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Musik Bersama 🎵',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Dengarkan musik bareng',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        toolbarHeight: 64,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildConnectionStatus(),
            const SizedBox(height: 24),
            _buildCreateRoomSection(),
            const SizedBox(height: 20),
            _buildDivider(),
            const SizedBox(height: 20),
            _buildJoinRoomSection(),
            const SizedBox(height: 24),
            _buildTipsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? AppColors.success : AppColors.error,
                boxShadow: [
                  BoxShadow(
                    color: (_isConnected ? AppColors.success : AppColors.error)
                        .withOpacity(0.5),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _isConnected ? 'Terhubung ke server' : 'Belum terhubung',
              style: TextStyle(
                color: _isConnected ? AppColors.success : AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (!_isConnected)
              SizedBox(
                height: 34,
                child: ElevatedButton(
                  onPressed: _isConnecting ? null : _connectSocket,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Hubungkan',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateRoomSection() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Buat Room',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Bagikan lagu Spotify-mu ke teman',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _spotifyTokenController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Spotify Access Token',
                hintStyle: TextStyle(
                  color: AppColors.textMuted.withOpacity(0.5),
                ),
                prefixIcon: const Icon(
                  Icons.vpn_key_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
              maxLines: 1,
              obscureText: true,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: GradientButton(
                onPressed: _isConnected ? _createRoom : null,
                label: 'Buat Room Baru',
                icon: Icons.music_note_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.surfaceBorder)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'ATAU',
            style: TextStyle(
              color: AppColors.textMuted.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.surfaceBorder)),
      ],
    );
  }

  Widget _buildJoinRoomSection() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.group_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gabung Room',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Dengarkan lagu bareng teman',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomIdController,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 8,
              ),
              textAlign: TextAlign.center,
              maxLength: 6,
              inputFormatters: [
                UpperCaseTextFormatter(),
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              ],
              decoration: InputDecoration(
                hintText: '– – – – – –',
                hintStyle: TextStyle(
                  color: AppColors.textMuted.withOpacity(0.3),
                  fontSize: 18,
                  letterSpacing: 8,
                ),
                counterText: '',
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isConnected ? _joinRoom : null,
                icon: const Icon(Icons.login_rounded, size: 20),
                label: const Text(
                  'Gabung Room',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.surfaceLight,
                  disabledForegroundColor: AppColors.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipsCard() {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lightbulb_outline_rounded,
                color: AppColors.info,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tips',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Dapatkan Spotify Access Token dari developer.spotify.com untuk membuat room.',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
