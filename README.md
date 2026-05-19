# Revoluchat Backend 🚀

[![Revoluchat Go SDK](https://img.shields.io/badge/Revoluchat-Go_SDK-00ADD8?style=for-the-badge&logo=go)](https://github.com/oririfai/revoluchat-go-sdk)

An enterprise-grade, multi-tenant real-time chat infrastructure built with **Elixir**, **Phoenix Channels**, and **Phoenix LiveView**.

Revoluchat serves as the central hub (BFF) that orchestrates real-time communication, supporting both a **Normal Tier** (internal Elixir logic) and an **Advance Tier** (offloaded to a high-performance Go microservice).

---

## 🏗️ Architecture

- **Engine**: Elixir/Phoenix (BEAM) for high-concurrency WebSocket management.
- **Dual Tier Architecture**:
  - **Normal Tier**: Native Elixir/Postgres implementation for standard chat needs.
  - **Advance Tier**: Offloads core messaging, groups, and calls to a Go backend via **gRPC**.
- **Primary DB**: PostgreSQL (Storing conversations, messages, webhooks, and SDK metadata).
- **User Integration**: **gRPC** (Decoupled from User Service DB).
- **File Storage**: Cloudflare R2 / S3 / Cloudinary (Flexible storage adapters).
- **Workers**: Oban (PostgreSQL-backed background job processing).
- **WebRTC Signaling**: Orchestration for **LiveKit SFU** audio/video calls.

---

## 🌟 Enterprise Features

- **Built-in Admin Dashboard**: Fully featured back-office built with Phoenix LiveView and Petal Components to manage API Keys, Server Keys, Users, and System Settings.
- **Multi-Tenancy**: Strict data isolation using `tenant_id` and `app_id` at the database level.
- **Real-time Engine**: Sub-millisecond message delivery across Phoenix Channels.
- **Hybrid Tiering**: Choose between Elixir-native storage or Go-backed high-performance storage (`e.g your custom go backend service`).
- **Webhooks System**: Built-in HTTP client (`Req`) for firing real-time webhook events to external systems.
- **Advanced Groups**: Roles, Permissions, Membership controls, and Invitation system.
- **Security**:
  - JWT verification using RSA (RS256) with JWKS support.
  - API Keys & Server Keys for robust Service-to-Service authentication.
- **Flexible Storage**: Pluggable adapters for Cloudflare R2, AWS S3, and Cloudinary.

---

## 🚀 Getting Started

### Prerequisites

- Elixir 1.15+ & Erlang/OTP 26
- PostgreSQL 14+
- Object Storage (Cloudflare R2 or Cloudinary)
- LiveKit Server (for WebRTC calls - optional)

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
4. Setup database and compile assets:
   ```bash
   mix setup
   ```
5. Start the server:
   ```bash
   source .env && mix phx.server
   ```
   > Visit the Admin Dashboard at `http://localhost:4000` (if configured)

---

## 📡 Microservice Integration (gRPC)

Revoluchat strictly follows a decoupled microservice architecture. It does not manage user profiles directly but relies on your **User Service** via gRPC.

### 1. External User Service (Outbound)

Revoluchat acts as a **gRPC Client** to verify users. Your User Service MUST implement the contract defined in `priv/protos/user_v1/user.proto`.

**Configuration**: Set the endpoint in your `.env`:

```bash
USER_SERVICE_GRPC_ENDPOINT=localhost:50051
```

> [!TIP]
> **Faster Integration**: If your User Service is built with Go, use our [Revoluchat Go SDK](https://github.com/oririfai/revoluchat-go-sdk) to skip gRPC boilerplate.

### 2. Advance Tier (Outbound)

When configured for Advance Tier (`TIER_TYPE=advance`), Revoluchat offloads logic to a Go backend (`chatcx-be`) via gRPC. This allows for higher throughput and specialized message handling.

**Configuration**: Set the endpoint in your `.env`:

```bash
CHAT_SERVICE_GRPC_ENDPOINT=localhost:50055
```

---

## 📞 LiveKit WebRTC SFU Integration

Revoluchat uses a **LiveKit Selective Forwarding Unit (SFU)** architecture. The Phoenix Backend acts as a **Token Authorizer** and **Call Orchestrator**.

### Architecture Scope

- **Orchestration Layer (Phoenix)**: Handles `call:request`, `call:respond`, and `call:accepted` events over Phoenix Sockets. Generates `LiveKit JWT Tokens` for both parties.
- **Media Layer (LiveKit SFU)**: Client SDKs connect directly to LiveKit using the securely injected `livekit_url` and JWT tokens.

### ⚙️ Server Configuration

Update your `.env` with the LiveKit server credentials:

```bash
LIVEKIT_URL=http://localhost:7880
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=secret
```

---

## 🔐 Security & Payload Flow

1. **Client** (App) sends a **JWT** (RS256) during Socket initialization.
2. **Revoluchat** verifies the JWT signature dynamically using **JWKS** (JSON Web Key Set).
   - Ensure the `JWKS_URL` environment variable is set to your User Service's keys endpoint.
3. **Revoluchat** extracts the `user_id` from the `sub` claim.
4. **Revoluchat** calls the **User Service** via **gRPC** `GetUser(user_id)` to ensure the user is valid and active before granting a Socket connection.

---

## 📂 Project Structure

- `lib/revoluchat`: Core business logic, schemas, workers, and gRPC clients.
- `lib/revoluchat_web`: Phoenix Endpoint, Channels (Socket logic), LiveView Dashboards, and REST Controllers.
- `lib/revoluchat/grpc`: gRPC server/client implementations and proto generated modules.
- `priv/protos`: Protobuf definitions used across the ecosystem.
- `priv/repo/migrations`: Database schema versioning.

---

## 🛠️ Essential Commands

| Command              | Description                                        |
| -------------------- | -------------------------------------------------- |
| `mix setup`          | Install deps, setup DB, and build frontend assets. |
| `mix phx.server`     | Start the Phoenix development server.              |
| `mix test`           | Run the test suite.                                |
| `mix ecto.migrate`   | Apply database migrations.                         |
| `mix phx.gen.secret` | Generate a new `SECRET_KEY_BASE`.                  |
| `./gen_proto`        | Regenerate Elixir code from protos (if available). |

---

## 📄 License

MIT © [Achmad Rifai](https://github.com/oririfai)
