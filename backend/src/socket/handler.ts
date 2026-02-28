import { Server as SocketIOServer, Socket } from 'socket.io';
import { SpotifyService } from './spotify-service';
import { LyricsService, LyricLine } from './lyrics-service';

interface Room {
  id: string;
  hostId: string;
  hostSpotifyToken: string;
  members: Set<string>;
  currentTrackId: string | null;
  currentLyrics: LyricLine[] | null;
  isPlaying: boolean;
  progressMs: number;
  lastUpdate: number;
  pollInterval: NodeJS.Timeout | null;
}

const rooms = new Map<string, Room>();

function generateRoomId(): string {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
}

export function setupSocketHandlers(io: SocketIOServer) {
  io.on('connection', (socket: Socket) => {
    console.log(`[Socket] Connected: ${socket.id}`);

    // ─── CREATE ROOM (Host) ───
    socket.on('create_room', async (data: { spotifyToken: string; userId: string }) => {
      const roomId = generateRoomId();
      const room: Room = {
        id: roomId,
        hostId: socket.id,
        hostSpotifyToken: data.spotifyToken,
        members: new Set([socket.id]),
        currentTrackId: null,
        currentLyrics: null,
        isPlaying: false,
        progressMs: 0,
        lastUpdate: Date.now(),
        pollInterval: null,
      };

      rooms.set(roomId, room);
      socket.join(roomId);

      socket.emit('room_created', { roomId });
      console.log(`[Room] Created: ${roomId} by ${socket.id}`);

      // Start Spotify polling
      startPolling(io, roomId);
    });

    // ─── JOIN ROOM (Listener) ───
    socket.on('join_room', (data: { roomId: string }) => {
      const roomId = data.roomId.toUpperCase();
      const room = rooms.get(roomId);

      if (!room) {
        socket.emit('error_event', { message: 'Room tidak ditemukan' });
        return;
      }

      room.members.add(socket.id);
      socket.join(roomId);

      // Send current state to the new member
      socket.emit('room_joined', {
        roomId,
        currentTrackId: room.currentTrackId,
        lyrics: room.currentLyrics,
        isPlaying: room.isPlaying,
        progressMs: room.progressMs,
        timestamp: room.lastUpdate,
      });

      io.to(roomId).emit('member_count', { count: room.members.size });
      console.log(`[Room] ${socket.id} joined ${roomId} (${room.members.size} members)`);
    });

    // ─── LEAVE ROOM ───
    socket.on('leave_room', (data: { roomId: string }) => {
      handleLeaveRoom(io, socket, data.roomId);
    });

    // ─── DISCONNECT ───
    socket.on('disconnect', () => {
      console.log(`[Socket] Disconnected: ${socket.id}`);
      // Clean up: remove from all rooms
      for (const [roomId, room] of rooms.entries()) {
        if (room.members.has(socket.id)) {
          handleLeaveRoom(io, socket, roomId);
        }
      }
    });
  });
}

function handleLeaveRoom(io: SocketIOServer, socket: Socket, roomId: string) {
  const room = rooms.get(roomId);
  if (!room) return;

  room.members.delete(socket.id);
  socket.leave(roomId);

  // If host left, destroy the room
  if (socket.id === room.hostId) {
    if (room.pollInterval) clearInterval(room.pollInterval);
    io.to(roomId).emit('room_closed', { message: 'Host meninggalkan room' });
    rooms.delete(roomId);
    console.log(`[Room] Destroyed: ${roomId} (host left)`);
  } else {
    io.to(roomId).emit('member_count', { count: room.members.size });
    console.log(`[Room] ${socket.id} left ${roomId} (${room.members.size} members)`);
  }
}

function startPolling(io: SocketIOServer, roomId: string) {
  const room = rooms.get(roomId);
  if (!room) return;

  // Poll every 2.5 seconds
  room.pollInterval = setInterval(async () => {
    const currentRoom = rooms.get(roomId);
    if (!currentRoom) {
      clearInterval(room.pollInterval!);
      return;
    }

    try {
      const playback = await SpotifyService.getCurrentlyPlaying(currentRoom.hostSpotifyToken);

      if (!playback) {
        if (currentRoom.isPlaying) {
          currentRoom.isPlaying = false;
          io.to(roomId).emit('playback_update', {
            isPlaying: false,
            progressMs: 0,
            timestamp: Date.now(),
          });
        }
        return;
      }

      const newTrackId = playback.trackId;
      const trackChanged = newTrackId !== currentRoom.currentTrackId;

      currentRoom.isPlaying = playback.isPlaying;
      currentRoom.progressMs = playback.progressMs;
      currentRoom.lastUpdate = Date.now();

      if (trackChanged && newTrackId) {
        currentRoom.currentTrackId = newTrackId;

        // Fetch lyrics for the new track
        const lyrics = await LyricsService.getSyncedLyrics(
          playback.trackName,
          playback.artistName
        );
        currentRoom.currentLyrics = lyrics;

        io.to(roomId).emit('track_changed', {
          trackId: newTrackId,
          trackName: playback.trackName,
          artistName: playback.artistName,
          albumArt: playback.albumArt,
          durationMs: playback.durationMs,
          lyrics: lyrics,
        });
      }

      // Always send playback progress
      io.to(roomId).emit('playback_update', {
        isPlaying: playback.isPlaying,
        progressMs: playback.progressMs,
        timestamp: Date.now(),
      });

    } catch (error) {
      console.error(`[Polling] Error for room ${roomId}:`, error);
    }
  }, 2500);
}
