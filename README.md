# 🏺 Obelisk — An Elixir/Phoenix Memory Layer for Coding Agents

> **Obelisk** is a powerful memory-augmented AI system built with Elixir/Phoenix, providing intelligent chat capabilities powered by vector search and multiple LLM providers.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Elixir](https://img.shields.io/badge/elixir-~%3E%201.18-brightgreen.svg)](https://elixir-lang.org)
[![Phoenix](https://img.shields.io/badge/phoenix-~%3E%201.8-orange.svg)](https://phoenixframework.org)

## ✨ Features

### 🤖 **Multi-Provider LLM Support**
- **OpenAI** (GPT-4, GPT-3.5-turbo, GPT-4o-mini) with streaming
- **Anthropic** (Claude-3.5-Sonnet, Claude-3-Opus)  
- **Ollama** (Local models: Llama, Mistral, CodeLlama, etc.)
- Dynamic provider switching in real-time

### 🧠 **Memory & RAG (Retrieval-Augmented Generation)**
- **Vector embeddings** with pgvector for semantic search
- **Intelligent chunking** of text with configurable overlap
- **Context-aware responses** using relevant memory chunks
- **Session-based** and **global** memory management

### 🌐 **Multiple Interfaces** 
- **🖥️ Web UI** - Interactive LiveView chat interface with real-time updates
- **🔌 REST API** - Full HTTP API with Server-Sent Events (SSE) streaming  
- **⚡ WebSocket** - Real-time bi-directional chat via Phoenix Channels
- **💻 CLI** - Command-line interface with REPL and one-shot modes

### 📊 **Memory Management**
- **Memory Inspector** - Browse, search, and manage stored knowledge
- **Semantic search** across all stored memories
- **Memory statistics** and analytics dashboard
- **CRUD operations** for memories with confirmations

### ⚡ **Production Features**
- **Async processing** with Broadway pipeline for embeddings
- **Real-time updates** via Phoenix PubSub
- **Background job processing** for heavy operations
- **Comprehensive logging** and telemetry
- **Docker support** for easy deployment

## 🚀 Quick Start

### Prerequisites
- Elixir 1.18+ and Erlang/OTP 26+
- PostgreSQL with pgvector extension
- OpenAI API key (for default functionality)

### 1. Clone & Setup
```bash
git clone https://github.com/dhippley/Obelisk.git
cd obelisk
mix deps.get
```

### 2. Database Setup
```bash
# Using Docker (recommended)
docker-compose up -d

# Or manual PostgreSQL setup
createdb obelisk_dev
psql obelisk_dev -c "CREATE EXTENSION vector;"
```

### 3. Configuration
```bash
# Copy environment template
cp env.example .env

# Edit .env and add your OpenAI API key
export OPENAI_API_KEY="sk-your-openai-api-key"
```

### 4. Initialize Database
```bash
mix ecto.setup
```

### 5. Start the Application
```bash
mix phx.server
```

🎉 **Visit [localhost:4000](http://localhost:4000)** to start chatting!

## 🎯 Usage Examples

### Web Interface
Navigate to `http://localhost:4000/chat` for the interactive chat interface with:
- Real-time messaging with AI assistants
- Provider switching (OpenAI ↔ Anthropic ↔ Ollama)  
- Context display showing retrieved memories
- Session management and history
- Memory Inspector at `/memory`

### REST API
```bash
# Basic chat
curl -X POST http://localhost:4000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "What is Elixir?",
    "options": {
      "provider": "openai",
      "model": "gpt-4o-mini"
    }
  }'

# Streaming chat with SSE
curl -X POST http://localhost:4000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Explain Phoenix LiveView", 
    "stream": true,
    "options": {"provider": "anthropic"}
  }'

# Search memories
curl http://localhost:4000/api/v1/memory/search?q=elixir&k=5
```

### CLI Interface
```bash
# Interactive REPL mode
mix obelisk

# One-shot queries
mix obelisk "What is functional programming?"

# Help and options
mix obelisk --help
```

### WebSocket Integration
```javascript
// Connect to real-time chat
const socket = new Phoenix.Socket("/socket")
const channel = socket.channel("chat:session_1")

channel.join()
channel.push("new_message", {message: "Hello!"})
channel.on("response", response => console.log(response))
```

## 🔧 Configuration

Obelisk supports extensive configuration for different environments and use cases.

### Environment Variables

See [`env.example`](./env.example) for the complete list. Key variables:

```bash
# LLM Providers
OPENAI_API_KEY=sk-your-key
ANTHROPIC_API_KEY=sk-ant-your-key  
OLLAMA_BASE_URL=http://localhost:11434

# Database
DATABASE_URL=ecto://postgres:postgres@localhost/obelisk_dev

# Performance
ASYNC_EMBEDDING=true
EMBEDDING_BATCH_SIZE=20
BROADWAY_PROCESSORS=4
```

### Detailed Configuration Guide

📖 **See [CONFIG.md](./CONFIG.md)** for comprehensive configuration documentation covering:
- LLM provider setup
- Database configuration  
- Performance tuning
- Production deployment
- Security considerations

## 🏗️ Architecture

### Core Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web UI        │    │   REST API      │    │   CLI/REPL      │
│  (LiveView)     │    │  (Controllers)  │    │  (Mix Tasks)    │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                    ┌─────────────▼──────────────┐
                    │        Chat Module         │
                    │   (RAG Orchestration)      │
                    └─────────┬──────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          │                   │                   │
    ┌─────▼──────┐  ┌─────────▼───────┐  ┌───────▼────────┐
    │ LLM Router │  │ Vector Search   │  │ Memory Store   │  
    │(Providers) │  │  (pgvector)     │  │ (PostgreSQL)   │
    └────────────┘  └─────────────────┘  └────────────────┘
```

### Technology Stack

- **🔶 Elixir/OTP** - Concurrent, fault-tolerant runtime
- **🟠 Phoenix** - Web framework with LiveView for real-time UIs
- **🔵 PostgreSQL** - Primary database with pgvector for similarity search
- **🟢 Broadway** - Data processing pipelines for async embedding
- **⚪ Req** - HTTP client for LLM API integration
- **🟡 TailwindCSS** - Modern, utility-first styling

### Data Flow

1. **User Input** → Web UI, API, or CLI
2. **Memory Retrieval** → Vector similarity search in PostgreSQL
3. **Context Building** → RAG prompt construction with relevant memories
4. **LLM Processing** → Route to OpenAI, Anthropic, or Ollama
5. **Response Generation** → Stream or return complete response
6. **Memory Storage** → Background embedding and storage of new context

## 📚 API Reference

### Chat Endpoints
- `POST /api/v1/chat` - Send chat messages (supports streaming)
- `GET /api/v1/chat/:session_id` - Get conversation history

### Memory Endpoints  
- `GET /api/v1/memory/search` - Semantic search across memories
- `POST /api/v1/memory` - Create new memories
- `GET /api/v1/memory` - List all memories

### Session Endpoints
- `GET /api/v1/sessions` - List all chat sessions
- `POST /api/v1/sessions` - Create new session
- `DELETE /api/v1/sessions/:id` - Delete session

### WebSocket Events
- `chat:*` channels for real-time messaging
- Events: `new_message`, `stream_message`, `typing`, `history`

## 🧪 Development

### Running Tests
```bash
# All tests
mix test

# Specific test files
mix test test/obelisk/chat_test.exs
mix test test/obelisk_web/live/chat_live_test.exs

# With coverage
mix test --cover
```

### Code Quality
```bash
# Linting and formatting
mix precommit

# Individual tools
mix format
mix credo --strict
```

### Database Operations
```bash
# Create migration
mix ecto.gen.migration add_new_feature

# Run migrations
mix ecto.migrate

# Reset database
mix ecto.reset
```

## 🚀 Deployment

### Docker Deployment
```bash
# Build production image
docker build -t obelisk .

# Run with Docker Compose
docker-compose -f docker-compose.prod.yml up -d
```

### Manual Production Deployment
```bash
# Set production environment
export MIX_ENV=prod

# Install dependencies and compile
mix deps.get --only prod
mix compile

# Database setup
mix ecto.setup

# Build assets
mix assets.deploy

# Generate release
mix release

# Start the release
_build/prod/rel/obelisk/bin/obelisk start
```

### Environment Variables for Production
```bash
# Required
DATABASE_URL=ecto://user:pass@host:port/db
SECRET_KEY_BASE=$(mix phx.gen.secret)
OPENAI_API_KEY=sk-your-production-key
PHX_HOST=yourdomain.com
PHX_SERVER=true

# Recommended
ASYNC_EMBEDDING=true
EMBEDDING_BATCH_SIZE=50
BROADWAY_PROCESSORS=8
```

## 🤝 Contributing

We welcome contributions! Please see our [contribution guidelines](CONTRIBUTING.md) for details.

### Development Setup
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Run `mix precommit` to ensure code quality
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Phoenix Framework** team for the amazing web framework
- **pgvector** for efficient vector similarity search  
- **Broadway** for robust data processing pipelines
- **OpenAI**, **Anthropic**, and **Ollama** for powerful LLM capabilities

## 📞 Support

- **📖 Documentation**: [CONFIG.md](./CONFIG.md) for detailed setup
- **🐛 Issues**: [GitHub Issues](https://github.com/dhippley/Obelisk/issues)
- **💬 Discussions**: [GitHub Discussions](https://github.com/dhippley/Obelisk/discussions)

---

<div align="center">
  <strong>🏺 Built with Elixir • Powered by Phoenix • Augmented by AI 🏺</strong>
</div>