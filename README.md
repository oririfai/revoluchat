# Revoluchat Backend 🚀

An enterprise-grade, multi-tenant real-time chat infrastructure built with **Elixir** and **Phoenix Channels**.

Revoluchat is designed as a standalone messaging service that integrates seamlessly with your existing microservices ecosystem via **gRPC** and **Webhooks**.

## 🏗️ Architecture

- **Engine**: Elixir/Phoenix (BEAM) for high-concurrency WebSocket management.
- **Primary DB**: PostgreSQL (Storing conversations, messages, and SDK metadata).
- **User Integration**: **gRPC** (Decoupled from User Service DB).
- **File Storage**: MinIO / S3 for media attachments.
- **Workers**: Oban (PostgreSQL-backed background job processing).
- **Monitoring**: Prometheus & Grafana integration.

## 🌟 Enterprise Features

- **Multi-Tenancy**: Strict data isolation using `tenant_id` and `app_id` at the database level.
- **Real-time Engine**: Sub-millisecond message delivery across Phoenix Channels.
- **Decoupled User Store**: Does not own user data; verifies users via external gRPC calls.
- **Security**: JWT verification using RSA (RS256) with JWKS support.
- **Scalability**: Stateless architecture ready for horizontal scaling behind a load balancer.

## 🚀 Getting Started

### Prerequisites

- Elixir 1.15+ & Erlang/OTP 26
- PostgreSQL 14+
- MinIO (for local media storage)

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
  // Dipanggil oleh Revoluchat setiap kali user mencoba connect ke Socket
  // atau saat pengiriman pesan untuk validasi & fecth metadata.
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

### 2. Conversation Service (Inbound)

Revoluchat acts as a **gRPC Server** allowing your backend to manage chat rooms administratively.

#### `chat.proto`

```proto
service ConversationService {
  // Membuat atau mengambil percakapan (1-on-1) antara dua user.
  rpc CreateConversation(CreateConversationRequest) returns (CreateConversationResponse);
}
```

---

## 🔐 Security & Payload Flow

1. **Client** (App) mengirimkan **JWT** (RS256) saat inisialisasi Socket.
2. **Revoluchat** memverifikasi tanda tangan JWT menggunakan **JWKS** (Public Key).
3. **Revoluchat** mengekstrak `user_id` dari claim `sub`.
4. **Revoluchat** memanggil **User Service** via **gRPC** `GetUser(user_id)` untuk memastikan user tersebut valid dan aktif sebelum mengizinkan koneksi Socket.

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

## 📄 License

MIT © [Achmad Rifai](https://github.com/achmadrifai)
