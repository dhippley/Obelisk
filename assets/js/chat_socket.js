/**
 * WebSocket Chat Client for Obelisk
 * 
 * Provides a JavaScript interface for real-time chat over WebSockets.
 * Integrates with Phoenix Channels for bi-directional communication.
 */

import { Socket } from "phoenix"

class ChatSocket {
  constructor(socketPath = "/socket") {
    this.socket = new Socket(socketPath, {
      // params: {token: userToken} // Authentication token if needed
    })
    
    this.channel = null
    this.sessionName = null
    this.callbacks = {
      onConnect: () => {},
      onDisconnect: () => {},
      onMessage: () => {},
      onTyping: () => {},
      onError: () => {},
      onHistoryLoaded: () => {},
      onHistoryCleared: () => {},
      onStreamStart: () => {},
      onStreamChunk: () => {},
      onStreamComplete: () => {},
      onStreamError: () => {}
    }
    
    this.setupSocketEvents()
  }
  
  /**
   * Setup socket-level event handlers
   */
  setupSocketEvents() {
    this.socket.onOpen(() => {
      console.log("Connected to WebSocket")
      this.callbacks.onConnect()
    })
    
    this.socket.onError((error) => {
      console.error("WebSocket error:", error)
      this.callbacks.onError(error)
    })
    
    this.socket.onClose((event) => {
      console.log("WebSocket disconnected:", event)
      this.callbacks.onDisconnect(event)
    })
  }
  
  /**
   * Connect to the WebSocket server
   */
  connect() {
    this.socket.connect()
    return this
  }
  
  /**
   * Join a chat session
   */
  joinSession(sessionName) {
    if (this.channel) {
      this.leaveSession()
    }
    
    this.sessionName = sessionName
    this.channel = this.socket.channel(`chat:${sessionName}`, {})
    
    this.setupChannelEvents()
    
    return new Promise((resolve, reject) => {
      this.channel.join()
        .receive("ok", (response) => {
          console.log(`Joined chat session: ${sessionName}`)
          resolve(response)
        })
        .receive("error", (response) => {
          console.error(`Failed to join session: ${sessionName}`, response)
          reject(response)
        })
    })
  }
  
  /**
   * Leave the current chat session
   */
  leaveSession() {
    if (this.channel) {
      this.channel.leave()
      this.channel = null
      this.sessionName = null
    }
    return this
  }
  
  /**
   * Setup channel-level event handlers
   */
  setupChannelEvents() {
    if (!this.channel) return
    
    // New message from other users or assistant
    this.channel.on("new_message", (message) => {
      console.log("Received message:", message)
      this.callbacks.onMessage(message)
    })
    
    // Typing indicators
    this.channel.on("typing", (data) => {
      this.callbacks.onTyping(data)
    })
    
    // Chat history when joining
    this.channel.on("chat_history", (data) => {
      console.log("Received chat history:", data)
      this.callbacks.onHistoryLoaded(data.history)
    })
    
    // History cleared event
    this.channel.on("history_cleared", (data) => {
      console.log("Chat history cleared:", data)
      this.callbacks.onHistoryCleared(data)
    })
    
    // Streaming events
    this.channel.on("stream_start", (data) => {
      console.log("Stream started:", data)
      this.callbacks.onStreamStart(data)
    })
    
    this.channel.on("stream_chunk", (data) => {
      this.callbacks.onStreamChunk(data)
    })
    
    this.channel.on("stream_complete", (data) => {
      console.log("Stream completed:", data)
      this.callbacks.onStreamComplete(data)
    })
    
    this.channel.on("stream_error", (data) => {
      console.error("Stream error:", data)
      this.callbacks.onStreamError(data)
    })
  }
  
  /**
   * Send a chat message
   */
  sendMessage(message, options = {}) {
    if (!this.channel) {
      throw new Error("Not connected to a chat session")
    }
    
    return new Promise((resolve, reject) => {
      this.channel.push("new_message", { message, options })
        .receive("ok", resolve)
        .receive("error", reject)
    })
  }
  
  /**
   * Send a streaming message
   */
  sendStreamMessage(message, options = {}) {
    if (!this.channel) {
      throw new Error("Not connected to a chat session")
    }
    
    return new Promise((resolve, reject) => {
      this.channel.push("stream_message", { message, options })
        .receive("ok", resolve)
        .receive("error", reject)
    })
  }
  
  /**
   * Send typing indicator
   */
  sendTyping(isTyping, user = "user") {
    if (!this.channel) return
    
    this.channel.push("typing", { typing: isTyping, user })
  }
  
  /**
   * Request chat history
   */
  getHistory(maxHistory = 50) {
    if (!this.channel) {
      throw new Error("Not connected to a chat session")
    }
    
    return new Promise((resolve, reject) => {
      this.channel.push("get_history", { max_history: maxHistory })
        .receive("ok", resolve)
        .receive("error", reject)
    })
  }
  
  /**
   * Clear chat history
   */
  clearHistory() {
    if (!this.channel) {
      throw new Error("Not connected to a chat session")
    }
    
    return new Promise((resolve, reject) => {
      this.channel.push("clear_history", {})
        .receive("ok", resolve)
        .receive("error", reject)
    })
  }
  
  /**
   * Set event callbacks
   */
  on(event, callback) {
    if (this.callbacks.hasOwnProperty(`on${event.charAt(0).toUpperCase()}${event.slice(1)}`)) {
      this.callbacks[`on${event.charAt(0).toUpperCase()}${event.slice(1)}`] = callback
    }
    return this
  }
  
  /**
   * Disconnect from WebSocket
   */
  disconnect() {
    this.leaveSession()
    this.socket.disconnect()
    return this
  }
  
  /**
   * Check if connected to a session
   */
  isConnected() {
    return this.channel && this.socket.isConnected()
  }
  
  /**
   * Get current session name
   */
  getCurrentSession() {
    return this.sessionName
  }
}

// Usage example:
/*
const chatSocket = new ChatSocket()
  .on('connect', () => console.log('Connected to chat'))
  .on('message', (msg) => console.log('New message:', msg))
  .on('typing', (data) => console.log('Typing:', data))
  .on('streamChunk', (chunk) => console.log('Stream chunk:', chunk.content))

chatSocket.connect()

// Join a session
chatSocket.joinSession('my-session').then(() => {
  // Send a message
  chatSocket.sendMessage('Hello, world!')
  
  // Send a streaming message
  chatSocket.sendStreamMessage('Tell me about Elixir')
})
*/

export default ChatSocket
