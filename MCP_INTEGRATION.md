# 🔌 Obelisk MCP Server Integration Guide

This guide shows how to integrate Obelisk's Model Context Protocol (MCP) server with AI assistants like Claude Desktop, Cursor, and other MCP-compatible clients.

## 🚀 Quick Start

### 1. Start the MCP Server

```bash
# In your Obelisk project directory
mix obelisk --mode mcp
```

The server will start and listen for JSON-RPC 2.0 messages on stdin/stdout.

### 2. Test the Server

You can test the server manually using JSON-RPC messages:

```bash
# List available tools
echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}' | mix obelisk --mode mcp

# Call the echo tool
echo '{"jsonrpc": "2.0", "id": 2, "method": "tools/call", "params": {"name": "echo", "arguments": {"message": "Hello, MCP!"}}}' | mix obelisk --mode mcp
```

## 🔧 Tool Integrations

### Available Tools

Obelisk provides three built-in tools:

#### 1. **Echo Tool** (`echo`)
- **Purpose**: Test connectivity and basic functionality
- **Parameters**:
  - `message` (string, required): Message to echo back
- **Example**:
  ```json
  {
    "name": "echo",
    "arguments": {"message": "Hello, World!"}
  }
  ```

#### 2. **Memory Search Tool** (`memory_search`)
- **Purpose**: Search through stored memories using semantic similarity
- **Parameters**:
  - `query` (string, required): Search query
  - `k` (integer, optional): Number of results (default: 5)
  - `session_id` (string, optional): Session scope
  - `threshold` (number, optional): Similarity threshold (default: 0.7)
- **Example**:
  ```json
  {
    "name": "memory_search", 
    "arguments": {
      "query": "Elixir programming patterns",
      "k": 10,
      "threshold": 0.8
    }
  }
  ```

#### 3. **Chat Tool** (`chat`)
- **Purpose**: Send messages to Obelisk's RAG-enabled chat system
- **Parameters**:
  - `message` (string, required): Message to send
  - `session_name` (string, optional): Conversation session
  - `provider` (string, optional): LLM provider (openai, anthropic, ollama)
  - `model` (string, optional): Specific model to use
- **Example**:
  ```json
  {
    "name": "chat",
    "arguments": {
      "message": "Explain functional programming in Elixir",
      "provider": "anthropic",
      "model": "claude-3-5-sonnet-20241022"
    }
  }
  ```

## 🖥️ Editor Integrations

### Claude Desktop Integration

Add Obelisk to your Claude Desktop configuration:

#### macOS Configuration

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "obelisk": {
      "command": "mix",
      "args": ["obelisk", "--mode", "mcp"],
      "cwd": "/path/to/your/obelisk/project",
      "env": {
        "OPENAI_API_KEY": "your-openai-api-key-here",
        "DATABASE_URL": "ecto://postgres:postgres@localhost/obelisk_dev"
      }
    }
  }
}
```

#### Windows Configuration

Edit `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "obelisk": {
      "command": "mix.bat",
      "args": ["obelisk", "--mode", "mcp"],
      "cwd": "C:\\path\\to\\your\\obelisk\\project",
      "env": {
        "OPENAI_API_KEY": "your-openai-api-key-here",
        "DATABASE_URL": "ecto://postgres:postgres@localhost/obelisk_dev"
      }
    }
  }
}
```

### Cursor Integration

Cursor supports MCP servers through its settings. Add to your Cursor configuration:

1. Open Cursor Settings (Cmd/Ctrl + ,)
2. Navigate to Extensions → MCP
3. Add a new server:

```json
{
  "name": "obelisk",
  "command": "mix",
  "args": ["obelisk", "--mode", "mcp"],
  "cwd": "/path/to/your/obelisk/project",
  "env": {
    "OPENAI_API_KEY": "your-openai-api-key-here"
  }
}
```

### Generic MCP Client Integration

For other MCP-compatible clients, use these connection details:

- **Protocol**: JSON-RPC 2.0
- **Transport**: stdio
- **Command**: `mix obelisk --mode mcp`
- **Working Directory**: Your Obelisk project root
- **Environment**: Ensure required environment variables are set

## 🔍 Usage Examples

### Example 1: Search Your Memory

**AI Assistant Prompt:**
> "Can you search my memories for information about Elixir GenServers?"

**MCP Call:**
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "memory_search",
    "arguments": {
      "query": "Elixir GenServers",
      "k": 5
    }
  }
}
```

### Example 2: Chat with Context

**AI Assistant Prompt:**
> "Ask Obelisk to explain the differences between Task and GenServer"

**MCP Call:**
```json
{
  "jsonrpc": "2.0", 
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "chat",
    "arguments": {
      "message": "What are the key differences between Task and GenServer in Elixir?",
      "provider": "openai"
    }
  }
}
```

### Example 3: Test Connection

**AI Assistant Prompt:**
> "Test the connection to Obelisk"

**MCP Call:**
```json
{
  "jsonrpc": "2.0",
  "id": 3,
  "method": "tools/call", 
  "params": {
    "name": "echo",
    "arguments": {
      "message": "Connection test successful!"
    }
  }
}
```

## 🛠️ Troubleshooting

### Common Issues

#### 1. **Server Won't Start**
```bash
Error: Could not start MCP server
```

**Solution:** Ensure all dependencies are installed and the database is running:
```bash
mix deps.get
docker-compose up -d  # Start PostgreSQL
mix ecto.setup       # Initialize database
```

#### 2. **Tool Calls Fail**
```json
{"error": {"code": -32602, "message": "Tool execution failed"}}
```

**Solutions:**
- Check that required environment variables are set (OPENAI_API_KEY, etc.)
- Verify database connection
- Check tool parameters match the expected schema

#### 3. **Memory Search Returns No Results**
```json
{"result": {"results": [], "total_found": 0}}
```

**Solutions:**
- Add some memories first using the web UI or CLI
- Lower the similarity threshold
- Try broader search terms

### Debugging

#### Enable Debug Logging
Set the log level to debug for more verbose output:

```bash
export LOG_LEVEL=debug
mix obelisk --mode mcp
```

#### Manual Testing
Test the server manually without an MCP client:

```bash
# Start server in one terminal
mix obelisk --mode mcp

# In another terminal, send test messages
echo '{"jsonrpc": "2.0", "id": 1, "method": "ping"}' | nc localhost -
```

#### Check Server Health
Use the ping method to verify server health:

```json
{"jsonrpc": "2.0", "id": 1, "method": "ping"}
```

Expected response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "status": "ok",
    "server": "obelisk-mcp", 
    "version": "0.1.0",
    "timestamp": "2025-01-01T12:00:00Z"
  }
}
```

## 🔒 Security Considerations

### Environment Variables
Never include sensitive API keys in configuration files. Use environment variables:

```bash
# .env file (add to .gitignore)
OPENAI_API_KEY=sk-your-secret-key
ANTHROPIC_API_KEY=sk-ant-your-secret-key
DATABASE_URL=ecto://postgres:password@localhost/obelisk_dev
```

### Access Control
Consider implementing access controls for production deployments:

- Rate limiting for tool calls
- Session-based permissions
- Audit logging for tool usage
- Network restrictions

### Data Privacy
- Memory searches may return sensitive information
- Chat responses are processed by external LLM providers
- Consider data residency requirements for your use case

## 📚 Advanced Usage

### Custom Tools
You can extend Obelisk by creating custom tools:

```elixir
defmodule MyApp.Tools.CustomTool do
  @behaviour Obelisk.Tool

  @impl true
  def spec do
    %{
      name: "custom_tool",
      description: "My custom tool",
      params: %{
        type: "object",
        properties: %{
          input: %{type: "string", description: "Tool input"}
        },
        required: ["input"]
      }
    }
  end

  @impl true
  def call(%{"input" => input}, _ctx) do
    {:ok, %{output: "Processed: #{input}"}}
  end
end
```

Register the tool in `lib/obelisk/tooling.ex`:

```elixir
@tools [
  Obelisk.Tools.Echo,
  Obelisk.Tools.Memory,
  Obelisk.Tools.Chat,
  MyApp.Tools.CustomTool  # Add your custom tool
]
```

### Production Deployment

For production deployments, consider:

1. **Process Supervision**: Use a proper supervisor tree
2. **Health Monitoring**: Implement health check endpoints  
3. **Graceful Shutdown**: Handle SIGTERM signals properly
4. **Resource Limits**: Set memory and CPU limits
5. **Logging**: Use structured logging with proper log levels

## 🤝 Contributing

To contribute new tools or improvements:

1. Fork the repository
2. Create a feature branch
3. Add your tool with tests
4. Update documentation
5. Submit a pull request

For questions or support, please open an issue on GitHub.

---

## 📖 References

- [Model Context Protocol Specification](https://spec.modelcontextprotocol.io/)
- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)  
- [Claude Desktop MCP Guide](https://claude.ai/docs/mcp)
- [Cursor Documentation](https://cursor.sh/docs)
