# Obelisk Configuration Guide

This guide covers how to configure Obelisk for development and production environments.

## Quick Start

1. **Copy environment template:**
   ```bash
   cp env.example .env
   ```

2. **Set required environment variables:**
   ```bash
   # Minimum required for basic functionality
   export OPENAI_API_KEY="sk-your-openai-key"
   export DATABASE_URL="ecto://postgres:postgres@localhost/obelisk_dev"
   ```

3. **Start the application:**
   ```bash
   source .env
   mix deps.get
   mix ecto.setup
   mix phx.server
   ```

## Configuration Overview

### Core Components

Obelisk uses a multi-layered configuration approach:

- **`config/config.exs`** - Application-wide defaults
- **`config/dev.exs`** - Development overrides  
- **`config/prod.exs`** - Production-specific settings
- **`config/runtime.exs`** - Runtime environment variables
- **`env.example`** - Environment variable template

## LLM Provider Configuration

### OpenAI (Default Provider)

```bash
# Required
OPENAI_API_KEY=sk-your-openai-key

# Optional  
OPENAI_MODEL=gpt-4o-mini          # Default model
OPENAI_BASE_URL=https://api.openai.com/v1
```

**Supported Models:**
- `gpt-4o-mini` (recommended for development)
- `gpt-4o` 
- `gpt-4`
- `gpt-3.5-turbo`

### Anthropic (Claude)

```bash
# Required for Anthropic support
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key

# Optional
ANTHROPIC_MODEL=claude-3-5-sonnet-20241022
ANTHROPIC_BASE_URL=https://api.anthropic.com/v1
```

**Supported Models:**
- `claude-3-5-sonnet-20241022` (recommended)
- `claude-3-opus-20240229`
- `claude-3-haiku-20240307`

### Ollama (Local Models)

```bash
# Required (install Ollama first)
OLLAMA_BASE_URL=http://localhost:11434

# Optional
OLLAMA_MODEL=llama3.2             # Default model
OLLAMA_TIMEOUT=60000              # Timeout in milliseconds
```

**Setup Ollama:**
```bash
# Install Ollama (macOS)
brew install ollama

# Start Ollama service
ollama serve

# Pull a model
ollama pull llama3.2
```

## Database Configuration

### Development

```bash
# PostgreSQL with pgvector extension
DATABASE_URL=ecto://postgres:postgres@localhost/obelisk_dev
POOL_SIZE=10
```

**Setup PostgreSQL with pgvector:**
```bash
# Using Docker (recommended)
docker-compose up -d

# Or manual setup
createdb obelisk_dev
psql obelisk_dev -c "CREATE EXTENSION vector;"
```

### Production

```bash
# Full connection string
DATABASE_URL=ecto://user:pass@host:port/database
POOL_SIZE=20

# Enable IPv6 if needed
ECTO_IPV6=true
```

## Memory & Embedding Configuration

### Embedding Settings

```bash
# Provider for generating embeddings
EMBEDDING_PROVIDER=openai
EMBEDDING_MODEL=text-embedding-3-small
EMBEDDING_DIMENSIONS=1536
```

### Memory Processing

```bash
# Text chunking settings
MEMORY_CHUNK_SIZE=1000            # Characters per chunk
MEMORY_CHUNK_OVERLAP=200          # Overlap between chunks

# Retrieval settings  
DEFAULT_RETRIEVAL_K=5             # Number of chunks to retrieve
DEFAULT_SIMILARITY_THRESHOLD=0.7  # Minimum similarity score
```

## Performance Configuration

### Async Processing

```bash
# Enable background processing
ASYNC_EMBEDDING=true              # true for production, false for dev

# Broadway pipeline settings
EMBEDDING_BATCH_SIZE=20           # Items per batch
BROADWAY_PROCESSORS=4             # Number of processors
BROADWAY_BATCH_TIMEOUT=5000       # Batch timeout (ms)
```

### Development Performance

```bash
# Faster feedback in development
ASYNC_EMBEDDING=false
EMBEDDING_BATCH_SIZE=5
BROADWAY_PROCESSORS=2
```

## Production Deployment

### Required Environment Variables

```bash
# Core production variables
DATABASE_URL=ecto://user:pass@host:port/db
SECRET_KEY_BASE=$(mix phx.gen.secret)
PHX_HOST=yourdomain.com
PHX_SERVER=true

# LLM Provider (choose one or more)  
OPENAI_API_KEY=sk-your-key
# ANTHROPIC_API_KEY=sk-ant-your-key
# OLLAMA_BASE_URL=http://ollama-server:11434
```

### Performance Tuning

```bash
# Production performance settings
POOL_SIZE=20                      # Database connections
ASYNC_EMBEDDING=true              # Enable background processing
EMBEDDING_BATCH_SIZE=50           # Larger batches
BROADWAY_PROCESSORS=8             # More processors
BROADWAY_BATCH_TIMEOUT=10000      # Longer timeout
```

### SSL Configuration

```bash
# Enable HTTPS (recommended)
SOME_APP_SSL_KEY_PATH=/path/to/key.pem  
SOME_APP_SSL_CERT_PATH=/path/to/cert.pem
```

## Configuration Validation

### Test Your Configuration

```bash
# Validate database connection
mix ecto.setup

# Test LLM providers
iex -S mix
```

```elixir
# In IEx, test each provider
Obelisk.LLM.Router.available_providers()
Obelisk.LLM.Router.chat([%{role: "user", content: "Hello"}], %{provider: "openai"})
```

### Configuration Health Check

The application provides endpoints to check configuration:

```bash
# Check API health
curl http://localhost:4000/api/v1/health

# Test chat functionality  
curl -X POST http://localhost:4000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, world!"}'
```

## Troubleshooting

### Common Issues

**1. Missing API Keys**
```bash
Error: OPENAI_API_KEY environment variable is required
```
Solution: Set the API key in your environment or `.env` file.

**2. Database Connection Issues**
```bash
Error: tcp connect (localhost:5432): connection refused
```
Solution: Start PostgreSQL and ensure pgvector extension is installed.

**3. Ollama Not Available**
```bash
Error: Ollama server not running
```
Solution: Start Ollama service with `ollama serve`.

**4. Permission Errors**
```bash
Error: permission denied for database
```
Solution: Ensure your database user has the required permissions.

### Debug Mode

Enable verbose logging for troubleshooting:

```bash
# Development
export LOG_LEVEL=debug

# Or in config/dev.exs
config :logger, level: :debug
```

## Security Considerations

### API Keys
- Store API keys in environment variables, never in code
- Use different keys for development and production
- Rotate keys regularly
- Monitor API usage and costs

### Database Security
- Use strong passwords for database users
- Enable SSL for database connections in production
- Restrict database access to application servers only

### Network Security
- Use HTTPS in production
- Configure proper CORS settings
- Implement rate limiting for API endpoints

## Monitoring & Observability

### Logging Configuration

```elixir
# config/prod.exs
config :logger, 
  level: :info,
  backends: [:console, {LoggerJSON, :console}]
```

### Metrics & Telemetry

Obelisk includes built-in telemetry for:
- LLM API calls and latency
- Embedding processing performance  
- Database query performance
- Memory retrieval metrics

Access metrics at: `http://localhost:4000/dashboard`

## Advanced Configuration

### Custom Providers

You can extend Obelisk with custom LLM providers by implementing the `Obelisk.LLM` behaviour:

```elixir
defmodule MyCustomProvider do
  @behaviour Obelisk.LLM
  
  def chat(messages, opts), do: # your implementation
  def stream_chat(messages, opts, callback), do: # your implementation
end
```

### Custom Embedding Models

Similarly, you can implement custom embedding providers for specialized use cases.

## Getting Help

- **Documentation**: Check the built-in docs with `mix docs`
- **Configuration**: Review `config/` files for all available options
- **Examples**: See `env.example` for complete environment setup
- **Logs**: Check application logs for detailed error information
