import { randomUUID } from 'node:crypto';
import cors from 'cors';
import express from 'express';
import { AccessToken, RoomServiceClient } from 'livekit-server-sdk';
import { config } from './config.js';

const app = express();
app.disable('x-powered-by');
app.use(
  cors({
    origin: config.corsOrigin === '*' ? true : config.corsOrigin.split(',').map((o) => o.trim()),
  }),
);
app.use(express.json({ limit: '16kb' }));

const roomService = new RoomServiceClient(config.livekitHttpUrl, config.apiKey, config.apiSecret);

const ROOM_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

function normalizeRoom(value: unknown): string | null {
  if (typeof value !== 'string') return null;
  const room = value.trim();
  return ROOM_PATTERN.test(room) ? room : null;
}

function normalizeDisplayName(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const name = value.trim().slice(0, 64);
  return name.length > 0 ? name : undefined;
}

function normalizeIdentity(value: unknown): string | undefined {
  if (typeof value !== 'string') return undefined;
  const identity = value.trim().slice(0, 64);
  return /^[A-Za-z0-9_-]{1,64}$/.test(identity) ? identity : undefined;
}

app.get('/healthz', (_req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

/**
 * Issue a LiveKit access token for a participant.
 * Body: { room: string, name?: string, identity?: string, canPublish?: boolean, canSubscribe?: boolean }
 */
app.post('/api/token', async (req, res) => {
  const room = normalizeRoom(req.body?.room);
  if (!room) {
    res.status(400).json({ error: 'room is required: 1-64 chars of a-z A-Z 0-9 _ -' });
    return;
  }

  const identity = normalizeIdentity(req.body?.identity) ?? `guest-${randomUUID().slice(0, 8)}`;
  const name = normalizeDisplayName(req.body?.name) ?? identity;
  const canPublish = req.body?.canPublish !== false;
  const canSubscribe = req.body?.canSubscribe !== false;

  const accessToken = new AccessToken(config.apiKey, config.apiSecret, {
    identity,
    name,
    ttl: config.tokenTtlSeconds,
  });
  accessToken.addGrant({
    roomJoin: true,
    room,
    canPublish,
    canSubscribe,
    canPublishData: canPublish,
  });

  const token = await accessToken.toJwt();

  res.json({
    token,
    url: config.livekitPublicUrl ?? config.livekitUrl,
    room,
    identity,
    name,
  });
});

/** List active rooms. */
app.get('/api/rooms', async (_req, res, next) => {
  try {
    const rooms = await roomService.listRooms();
    res.json({
      rooms: rooms.map((room) => ({
        name: room.name,
        numParticipants: room.numParticipants,
        maxParticipants: room.maxParticipants,
        createdAt: Number(room.creationTime ?? 0n) * 1000,
      })),
    });
  } catch (error) {
    next(error);
  }
});

/** Create a room ahead of time. Body: { name: string, emptyTimeout?: number, maxParticipants?: number } */
app.post('/api/rooms', async (req, res, next) => {
  const name = normalizeRoom(req.body?.name);
  if (!name) {
    res.status(400).json({ error: 'name is required: 1-64 chars of a-z A-Z 0-9 _ -' });
    return;
  }

  try {
    const room = await roomService.createRoom({
      name,
      emptyTimeout: Number(req.body?.emptyTimeout ?? 300),
      maxParticipants: Number(req.body?.maxParticipants ?? 20),
    });
    res.status(201).json({ name: room.name, numParticipants: room.numParticipants });
  } catch (error) {
    next(error);
  }
});

/** Delete (close) a room and disconnect all participants. */
app.delete('/api/rooms/:name', async (req, res, next) => {
  const name = normalizeRoom(req.params.name);
  if (!name) {
    res.status(400).json({ error: 'invalid room name' });
    return;
  }

  try {
    await roomService.deleteRoom(name);
    res.status(204).end();
  } catch (error) {
    next(error);
  }
});

app.use((_req, res) => {
  res.status(404).json({ error: 'not found' });
});

app.use((error: unknown, _req: express.Request, res: express.Response, _next: express.NextFunction) => {
  const message = error instanceof Error ? error.message : 'internal error';
  console.error('[api] request failed:', message);
  res.status(502).json({ error: 'livekit request failed', detail: message });
});

app.listen(config.port, () => {
  console.log(`[api] listening on http://localhost:${config.port}`);
  console.log(`[api] livekit http endpoint: ${config.livekitHttpUrl}`);
});
