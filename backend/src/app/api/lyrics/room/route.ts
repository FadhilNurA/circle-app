import { NextRequest, NextResponse } from 'next/server';

// GET /api/lyrics/rooms/:id — check if a room exists (optional REST endpoint)
export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const roomId = searchParams.get('roomId');

  if (!roomId) {
    return NextResponse.json({ error: 'roomId is required' }, { status: 400 });
  }

  // Room existence is managed by Socket.io in-memory.
  // This endpoint simply confirms the server is reachable.
  return NextResponse.json({
    message: 'Use Socket.IO to join rooms',
    socketPath: '/socket.io',
  });
}
