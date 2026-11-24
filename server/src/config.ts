import 'dotenv/config';

function toHttpUrl(url: string): string {
  return url.replace(/^ws(s?):\/\//, 'http$1://');
}

const livekitUrl = process.env.LIVEKIT_URL ?? 'ws://localhost:7880';

export const config = {
  port: Number(process.env.PORT ?? 8080),
  /** WebSocket URL handed to clients, e.g. wss://livekit.example.com */
  livekitUrl,
  /** HTTP(S) URL used by the server SDK to call LiveKit's RoomService. */
  livekitHttpUrl: process.env.LIVEKIT_HTTP_URL ?? toHttpUrl(livekitUrl),
  /** Optional public URL returned to clients when it differs from LIVEKIT_URL. */
  livekitPublicUrl: process.env.LIVEKIT_PUBLIC_URL || undefined,
  apiKey: process.env.LIVEKIT_API_KEY ?? 'devkey',
  apiSecret: process.env.LIVEKIT_API_SECRET ?? 'secret',
  tokenTtlSeconds: Number(process.env.TOKEN_TTL_SECONDS ?? 3600),
  corsOrigin: process.env.CORS_ORIGIN ?? '*',
} as const;

if (!config.apiKey || !config.apiSecret) {
  throw new Error('LIVEKIT_API_KEY and LIVEKIT_API_SECRET must be set');
}
