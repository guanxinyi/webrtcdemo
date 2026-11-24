# LiveKit Meet

基于 Flutter + LiveKit 的跨平台实时音视频应用，覆盖 **iOS / Android / Web / Windows / macOS**，并包含一个用于签发访问凭证的 Node.js 后端。

## 功能

- 实时音视频通话（多人群聊，自适应码率 + Dynacast）
- 加入前可预选摄像头 / 麦克风；进房后一键开关麦克风、摄像头
- 活跃说话人高亮、静音状态、网络质量指示
- 桌面端（Windows / macOS / 桌面浏览器）支持屏幕共享
- 房间号灵活输入，一键复制邀请信息
- 断线自动重连、异常断开提示与重试
- 后端提供 Token 签发、房间列表 / 创建 / 删除、健康检查

## 架构

```
┌──────────────────────────────┐
│  Flutter App (5 platforms)   │
│  livekit_client 2.x          │
└───────────┬──────────────────┘
            │ 1. POST /api/token (room, name)
            ▼
┌──────────────────────────────┐       2. 签发 JWT（API Key/Secret）
│  Token API (Node + TS)       │──────────────────────────────┐
│  Express + livekit-server-sdk│                              ▼
└───────────┬──────────────────┘                   ┌────────────────────┐
            │ 3. 返回 token + LiveKit ws URL       │  LiveKit Server    │
            └─────────────────────────────────────▶│  SFU (WebRTC)      │
                                                   └────────────────────┘
```

App 不直接持有 API Secret：先向 Token API 换取短期 JWT，再用 JWT 连接 LiveKit。

## 目录结构

```
.
├── app/                       # Flutter 应用（ios/android/web/windows/macos）
│   ├── lib/
│   │   ├── main.dart
│   │   ├── config.dart        # 编译期配置（API_BASE_URL 等）
│   │   ├── screens/           # 加入页 / 房间页
│   │   ├── services/          # Token API 客户端
│   │   ├── widgets/           # 视频宫格、工具栏
│   │   └── theme.dart
│   └── ...
├── server/                    # Node.js + TypeScript 后端
│   ├── src/index.ts           # Express 路由
│   ├── src/config.ts
│   └── Dockerfile
└── deploy/                    # LiveKit Server + Token API 编排
    ├── docker-compose.yml
    ├── livekit.yaml
    └── .env.example
```

## 快速开始

### 1. 启动后端和 LiveKit

方式 A：Docker Compose（推荐）

```bash
cd deploy
cp .env.example .env          # 按需修改密钥 / 公网地址
docker compose up -d --build
```

方式 B：本地分别启动

```bash
# 终端 1：LiveKit Server（dev 模式，密钥为 devkey/secret）
docker run --rm --network host livekit/livekit-server:v1.13.11 --dev --bind 0.0.0.0

# 终端 2：Token API
cd server
cp .env.example .env
npm install
npm run dev
```

验证：

```bash
curl http://localhost:8080/healthz
curl -X POST http://localhost:8080/api/token \
  -H 'Content-Type: application/json' \
  -d '{"room":"demo-room","name":"张三"}'
```

### 2. 运行 Flutter 应用

```bash
cd app
flutter pub get

# Web（本机浏览器）
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080

# Android（模拟器访问宿主机需用 10.0.2.2）
flutter run -d <device-id> \
  --dart-define=API_BASE_URL=http://10.0.2.2:8080

# iOS / macOS / Windows
flutter run -d <device-id> --dart-define=API_BASE_URL=http://<你的IP>:8080
```

> App 使用的 LiveKit 地址由 Token API 返回（`LIVEKIT_PUBLIC_URL`）。手机或其它设备测试时，务必把它改成客户端可访问的地址，例如 `ws://192.168.1.10:7880`。

### 3. 多人测试

同一房间号、不同昵称，在两台设备（或两个浏览器标签）加入即可看到彼此画面。

浏览器必须处于安全上下文才能采集摄像头/麦克风：`localhost` 或 HTTPS。

## 构建发布包

```bash
cd app

flutter build web --release --dart-define=API_BASE_URL=https://api.example.com
flutter build apk --release --dart-define=API_BASE_URL=https://api.example.com
flutter build ipa --release --dart-define=API_BASE_URL=https://api.example.com   # 需 macOS + Xcode
flutter build macos --release --dart-define=API_BASE_URL=https://api.example.com # 需 macOS
flutter build windows --release --dart-define=API_BASE_URL=https://api.example.com
```

> iOS / macOS 首次构建时需要配置签名（Xcode → Signing & Capabilities），并在真机上允许摄像头 / 麦克风权限；macOS 的沙盒权限已在 `Runner/*.entitlements` 中配置。

## 配置项

### Flutter（`--dart-define`）

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `API_BASE_URL` | `http://localhost:8080` | Token API 地址，也可在加入页手动修改 |
| `DEFAULT_ROOM` | `demo-room` | 加入页预填房间号 |

### Token API（`server/.env`）

| 变量 | 默认值 | 说明 |
| --- | --- | --- |
| `PORT` | `8080` | 服务端口 |
| `LIVEKIT_URL` | `ws://localhost:7880` | 返回给客户端的 WebSocket 地址 |
| `LIVEKIT_HTTP_URL` | 由 `LIVEKIT_URL` 推导 | 服务端调用 RoomService 的 HTTP 地址 |
| `LIVEKIT_PUBLIC_URL` | 同 `LIVEKIT_URL` | 可选，客户端实际使用的地址 |
| `LIVEKIT_API_KEY` | `devkey` | 必须与 LiveKit Server 一致 |
| `LIVEKIT_API_SECRET` | `secret` | 必须与 LiveKit Server 一致 |
| `TOKEN_TTL_SECONDS` | `3600` | Token 有效期 |
| `CORS_ORIGIN` | `*` | 允许的跨域来源，逗号分隔 |

## API

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| `GET` | `/healthz` | 健康检查 |
| `POST` | `/api/token` | 签发房间 Token，Body：`{ room, name?, identity?, canPublish?, canSubscribe? }` |
| `GET` | `/api/rooms` | 列出活跃房间 |
| `POST` | `/api/rooms` | 预创建房间，Body：`{ name, emptyTimeout?, maxParticipants? }` |
| `DELETE` | `/api/rooms/:name` | 关闭房间并断开所有人 |

## 网络与部署

LiveKit 需要放行的端口：

| 端口 | 协议 | 用途 |
| --- | --- | --- |
| 7880 | TCP | HTTP / WebSocket 信令 |
| 7881 | TCP | WebRTC over TCP（回退） |
| 7882 | UDP | WebRTC 媒体（UDP mux） |

公网部署时：

1. `deploy/.env` 中换成强随机 `LIVEKIT_API_KEY/SECRET`，并同步到 LiveKit（`LIVEKIT_KEYS`）。
2. 将 `livekit.yaml` 的 `use_external_ip` 设为 `true`（或有公网 IP 时配置 `node_ip`）。
3. 使用 Nginx/Caddy 为 7880 提供 TLS，客户端改用 `wss://`；Token API 也应置于 HTTPS 之后。
4. `CORS_ORIGIN` 收紧为实际 Web 域名。
5. 生产环境为 `/api/*` 增加鉴权（当前示例接口为公开演示性质）。

## 安全说明

- 仓库中的 `devkey/secret` 仅用于本地开发，请勿用于生产。
- Android 已开启 `usesCleartextTraffic` 以便连接本地 HTTP 服务；上线前应改为仅 HTTPS。
- Token 接口未做身份校验，任何能访问该接口的人都能加入房间，生产环境请接入你的登录体系。
- 屏幕共享仅在桌面端提供；移动端受系统限制（iOS 需要 Broadcast Extension，Android 需要 MediaProjection 前台服务），未在本示例中启用。

## 推送代码到 GitHub

本仓库已在本地完成初始化与提交。创建远端后执行：

```bash
# 方式一：使用 GitHub CLI
gh repo create livekit-meet --private --source . --push

# 方式二：先在 GitHub 网页创建空仓库，再手动关联
git remote add origin https://github.com/<your-name>/livekit-meet.git
git branch -M main
git push -u origin main
```

## 技术栈

- Flutter 3.50 / Dart 3.14
- [livekit_client](https://pub.dev/packages/livekit_client) 2.14
- LiveKit Server v1.13
- Node.js 20+ / TypeScript / Express 5 / livekit-server-sdk
#   w e b r t c d e m o  
 #   w e b r t c d e m o  
 