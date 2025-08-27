# Phase 2 API Endpoints - Demo Guide

This document demonstrates the new Phoenix API endpoints implemented in Phase 2.

## 🚀 Quick Start

Start the server:
```bash
mix phx.server
```

The API is now available at `http://localhost:4000`

## 📡 API Endpoints

### 1. Chat API (`/api/v1/chat`)

#### Regular Chat
```bash
curl -X POST http://localhost:4000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What is Elixir?",
    "session_id": "demo-session"
  }'
```

**Response:**
```json
{
  "response": "Elixir is a functional programming language...",
  "session_id": "demo-session", 
  "context_used": 2,
  "history_included": 0,
  "metadata": {
    "processing_time_ms": 0
  }
}
```

#### Streaming Chat (SSE)
```bash
curl -X POST http://localhost:4000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Tell me about Phoenix",
    "session_id": "demo-session",
    "stream": true
  }'
```

**Response (Server-Sent Events):**
```
data: {"type":"start","data":{"session_id":"demo-session","message":"Tell me about Phoenix"}}

data: {"type":"token","data":{"content":"Phoenix "}}

data: {"type":"token","data":{"content":"is "}}

data: {"type":"done","data":{"session_id":"demo-session","context_used":1}}
```

#### Get Chat History
```bash
curl http://localhost:4000/api/v1/chat/demo-session
```

### 2. Memory API (`/api/v1/memory`)

#### Store Memory
```bash
curl -X POST http://localhost:4000/api/v1/memory \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Elixir runs on the BEAM virtual machine",
    "kind": "fact",
    "metadata": {"source": "documentation"},
    "session_id": "demo-session"
  }'
```

#### Search Memory
```bash
curl -X POST http://localhost:4000/api/v1/memory/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "BEAM virtual machine",
    "k": 5,
    "threshold": 0.7
  }'
```

**Response:**
```json
{
  "query": "BEAM virtual machine",
  "results": [
    {
      "id": 1,
      "text": "Elixir runs on the BEAM virtual machine",
      "score": 0.9234,
      "memory_id": 1,
      "kind": "fact",
      "session_id": null
    }
  ],
  "count": 1,
  "parameters": {
    "k": 5,
    "threshold": 0.7,
    "include_global": true
  }
}
```

#### Streaming Search (SSE)
```bash
curl -X POST http://localhost:4000/api/v1/memory/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "Phoenix web framework",
    "stream": true
  }'
```

#### List Memories
```bash
curl "http://localhost:4000/api/v1/memory?limit=10"
```

### 3. Sessions API (`/api/v1/sessions`)

#### Create Session
```bash
curl -X POST http://localhost:4000/api/v1/sessions \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-session",
    "metadata": {"purpose": "demo"}
  }'
```

#### Get Session Details
```bash
curl http://localhost:4000/api/v1/sessions/my-session
```

**Response:**
```json
{
  "id": 1,
  "name": "my-session", 
  "metadata": {"purpose": "demo"},
  "created_at": "2025-01-01T00:00:00",
  "updated_at": "2025-01-01T00:00:00",
  "messages": [...],
  "memories": [...],
  "stats": {
    "message_count": 5,
    "memory_count": 3,
    "last_activity": "2025-01-01T00:05:00"
  }
}
```

#### Delete Session
```bash
curl -X DELETE http://localhost:4000/api/v1/sessions/my-session
```

## ⚡ Features

### ✅ Implemented
- **REST API endpoints** for chat, memory, and sessions
- **Server-Sent Events (SSE)** streaming for real-time responses
- **RAG (Retrieval-Augmented Generation)** with context injection
- **Vector similarity search** with configurable thresholds
- **Session management** with conversation history
- **Memory storage** with metadata and async embedding
- **Error handling** with informative error messages
- **Input validation** and parameter sanitization

### 🔄 Request/Response Patterns
- **JSON API** with consistent response format
- **Streaming responses** via SSE with structured events
- **Flexible parameters** with sensible defaults
- **Pagination support** for list endpoints
- **Status codes** following REST conventions

### 🛡️ Error Handling
- **400 Bad Request** for missing/invalid parameters
- **404 Not Found** for non-existent resources  
- **422 Unprocessable Entity** for validation errors
- **500 Internal Server Error** for system failures

## 🧪 Testing

Run API tests:
```bash
mix test test/obelisk_web/controllers/api/
```

All 14 API tests pass, covering:
- Chat message creation and history retrieval
- Memory storage, search, and listing
- Session management operations
- Error scenarios and edge cases
- Streaming parameter handling

## 🚀 Next Steps

Phase 2 continuation:
- **WebSocket support** for bi-directional real-time chat
- **LiveView interface** for interactive web UI
- **Provider switching** for different LLM backends

## 💡 Architecture Notes

- **Controller-based design** following Phoenix conventions
- **Modular functions** for regular vs streaming responses
- **Consistent error formatting** across all endpoints
- **Mock-friendly testing** with dependency injection
- **SSE implementation** with proper headers and chunked responses

The API is production-ready with proper error handling, validation, and testing coverage!
