# Revoluchat Backend 🚀

An enterprise-grade, multi-tenant real-time chat infrastructure built with **Elixir** and **Phoenix Channels**.

Revoluchat is designed as a standalone messaging service that integrates seamlessly with your existing microservices ecosystem via **gRPC** and **Webhooks**.

## 🏗️ Architecture

- **Engine**: Elixir/Phoenix (BEAM) for high-concurrency WebSocket management.
- **Primary DB**: PostgreSQL (Storing conversations, messages, and SDK metadata).
- **User Integration**: **gRPC** (Decoupled from User Service DB).
- **File Storage**: MinIO / S3 / Cloudinary (Flexible storage adapters).
- **Workers**: Oban (PostgreSQL-backed background job processing).
- **Monitoring**: Prometheus & Grafana integration.
- **WebRTC Signaling**: Ultra-low latency signaling relay via User Channels for P2P audio/video calls.

## 🌟 Enterprise Features

- **Multi-Tenancy**: Strict data isolation using `tenant_id` and `app_id` at the database level.
- **Real-time Engine**: Sub-millisecond message delivery across Phoenix Channels.
- **Decoupled User Store**: Does not own user data; verifies users via external gRPC calls.
- **Security**: JWT verification using RSA (RS256) with JWKS support.
- **Flexible Storage**: Pluggable adapters for MinIO, AWS S3, and Cloudinary.
- **Scalability**: Stateless architecture ready for horizontal scaling behind a load balancer.

## 🚀 Getting Started

### Prerequisites

- Elixir 1.15+ & Erlang/OTP 26
- PostgreSQL 14+
- Object Storage (MinIO for local, or Cloudinary account)

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   mix deps.get
   ```
3. Setup environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your local database and gRPC settings
   ```
4. Setup database:
   ```bash
   mix ecto.setup
   ```
5. Start the server:
   ```bash
   source .env && mix phx.server
   ```

## 📡 Microservice Integration (gRPC)

Revoluchat strictly follows a decoupled microservice architecture. It does not manage user profiles directly but relies on your **User Service** via gRPC.

### 1. External User Service (Outbound)

Revoluchat acts as a **gRPC Client** to verify users. Your User Service MUST implement the following Protobuf contract:

#### `user.proto`

```proto
syntax = "proto3";
package user.v1;

service UserService {
  // Called by Revoluchat whenever a user attempts to connect to a Socket
  // or during message sending for validation & metadata retrieval.
  rpc GetUser(GetUserRequest) returns (GetUserResponse);
}

message GetUserRequest {
  uint64 id = 1;
}

message GetUserResponse {
  uint64 id = 1;
  string uuid = 2;
  string name = 3;
  string phone = 4;
  string status = 5;      // e.g., "active", "suspended"
  bool is_kyc = 6;
  string avatar_url = 7;  // Avatar
}
```

#### Configuration

Set the endpoint in your `.env`:

```bash
USER_SERVICE_GRPC_ENDPOINT=user-service:50051
```

> [!TIP]
> **Faster Integration**: If your User Service is built with Go, use our [Revoluchat Go SDK](https://github.com/oririfai/revoluchat-go-sdk.git) to skip gRPC boilerplate and integrate with a simple "pointing" pattern.

### 2. Conversation Service (Inbound)

Revoluchat acts as a **gRPC Server** allowing your backend to manage chat rooms administratively.

#### `chat.proto`

```proto
service ConversationService {
  // Creates or retrieves an existing (1-on-1) conversation between two users.
  rpc CreateConversation(CreateConversationRequest) returns (CreateConversationResponse);
}
```

---

## 📞 LiveKit WebRTC SFU Integration

Revoluchat has migrated from a legacy Peer-to-Peer (P2P) signaling routing model to a highly scalable **LiveKit Selective Forwarding Unit (SFU)** architecture. The Phoenix Backend acts solely as a secure **Token Authorizer** and **Call Orchestrator**, while offloading heavy audio/video media routing to the LiveKit server.

### Architecture Scope
- **Orchestration Layer (Phoenix Backend)**: Handles the initial `call:request`, `call:respond`, and `call:accepted` events over ultra-fast Phoenix Sockets. It dynamically generates robust `LiveKit JWT Tokens` for both callers and receivers upon a successful call handshake.
- **Media Layer (LiveKit SFU)**: Client SDKs connect directly to LiveKit using the securely injected WebSocket payload `livekit_url` and JWT tokens, enabling massive multi-party scale.

### ⚙️ Server Configuration
You must have a LiveKit server running alongside your Elixir deployment. Update your `.env` with the LiveKit server credentials:

```bash
LIVEKIT_URL=http://localhost:7880
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=secret
```

### 📡 Android Mobile Local Development (Emulator Guide)

When developing Native Mobile SDKs, the Android Emulator treats `localhost` as *itself*, which breaks LiveKit WebRTC handshakes if the server points clients to `127.0.0.1`.

**The Solution**: Bind LiveKit and the Elixir Backend to your **Physical Wi-Fi/LAN IP Address** (e.g., `192.168.x.x`).

1. In the Elixir `.env` file, update the URL:
   ```env
   LIVEKIT_URL=http://192.168.x.x:7880
   ```
2. In your LiveKit Server's `livekit.yaml`, explicitly set the Node IP:
   ```yaml
   rtc:
     tcp_port: 7881
     node_ip: '192.168.x.x' # <~ Your Physical Machine's WiFi IP address
     use_external_ip: false
   ```

Restart both `livekit-server` and `revoluchat` docker containers. This guarantees that Android Emulators and physical phones on your local Wi-Fi will connect successfully to the WebRTC ICE streams without hitting IP resolution walls.

---

## 🔐 Security & Payload Flow

1. **Client** (App) sends a **JWT** (RS256) during Socket initialization.
2. **Revoluchat** verifies the JWT signature dynamically using **JWKS** (JSON Web Key Set).
   - Ensure the `JWKS_URL` environment variable is set to your User Service's keys endpoint.
   - Manual RSA public key files are deprecated and no longer required.
3. **Revoluchat** extracts the `user_id` from the `sub` claim.
4. **Revoluchat** calls the **User Service** via **gRPC** `GetUser(user_id)` to ensure the user is valid and active before granting a Socket connection.

## 📁 Project Structure

- `lib/revoluchat`: Core business logic and database schemas.
- `lib/revoluchat_web`: Phoenix Endpoint, Channels, and HTTP APIs.
- `lib/revoluchat/grpc`: gRPC server and client implementations.
- `priv/repo/migrations`: Database schema versioning.

## 🛠️ Commands

| Command              | Description                           |
| -------------------- | ------------------------------------- |
| `mix phx.server`     | Start the Phoenix development server. |
| `mix test`           | Run the test suite.                   |
| `mix ecto.migrate`   | Apply database migrations.            |
| `mix phx.gen.secret` | Generate a new `SECRET_KEY_BASE`.     |

## 🗺️ API Feature Highlights

### Call History Filtering
The `GET /api/v1/calls/history` endpoint now supports an optional `contact_id` query parameter. 
- **Usage**: `GET /api/v1/calls/history?contact_id=123`
- **Behavior**: Returns only the call history between the authenticated user and the specified contact.

## 📄 License

MIT © [Achmad Rifai](https://github.com/achmadrifai)
