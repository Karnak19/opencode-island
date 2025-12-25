import type { Plugin } from "@opencode-ai/plugin"
import { connect } from "net"
import { homedir } from "os"
import { join } from "path"

const SOCKET_PATH = join(homedir(), ".opencode-island", "socket")

// Track current session
let currentSessionId: string | null = null
let currentCwd: string | null = null

/**
 * Send event to Opencode Island via Unix socket
 */
function sendEvent(event: {
  type: string
  session_id: string
  payload: Record<string, unknown>
}): Promise<void> {
  return new Promise((resolve) => {
    const socket = connect(SOCKET_PATH)
    
    socket.on("connect", () => {
      const message = JSON.stringify({
        version: "1.0",
        type: event.type,
        timestamp: Date.now(),
        session_id: event.session_id,
        payload: event.payload,
      })
      socket.write(message)
      socket.end()
      resolve()
    })
    
    socket.on("error", (err) => {
      // Socket not available - Island app might not be running
      // Silently ignore
      resolve()
    })
    
    // Timeout after 1 second
    setTimeout(() => {
      socket.destroy()
      resolve()
    }, 1000)
  })
}

/**
 * Opencode Island Plugin
 * Sends session and tool events to the Opencode Island app
 */
export const OpencodeIslandPlugin: Plugin = async ({ directory }) => {
  currentCwd = directory
  
  return {
    // Generic event handler for all events
    event: async ({ event }) => {
      // Session created
      if (event.type === "session.created") {
        const data = event.properties as { sessionId?: string }
        if (data.sessionId) {
          currentSessionId = data.sessionId
          await sendEvent({
            type: "session_start",
            session_id: data.sessionId,
            payload: {
              cwd: currentCwd,
              model: "unknown", // Will be updated later
            },
          })
        }
      }
      
      // Session idle (finished processing)
      if (event.type === "session.idle" && currentSessionId) {
        await sendEvent({
          type: "session_update",
          session_id: currentSessionId,
          payload: {
            status: "idle",
          },
        })
      }
      
      // Session status update
      if (event.type === "session.status" && currentSessionId) {
        const data = event.properties as { status?: string }
        await sendEvent({
          type: "session_update",
          session_id: currentSessionId,
          payload: {
            status: data.status || "unknown",
          },
        })
      }
      
      // Session deleted/ended
      if (event.type === "session.deleted" && currentSessionId) {
        await sendEvent({
          type: "session_end",
          session_id: currentSessionId,
          payload: {},
        })
        currentSessionId = null
      }
      
      // Permission request (tool approval needed)
      if (event.type === "permission.updated" && currentSessionId) {
        const data = event.properties as {
          tool?: string
          toolInput?: Record<string, unknown>
          toolUseId?: string
        }
        if (data.tool) {
          await sendEvent({
            type: "tool_approval_needed",
            session_id: currentSessionId,
            payload: {
              tool: data.tool,
              tool_input: data.toolInput,
              tool_use_id: data.toolUseId,
              status: "waiting_for_approval",
            },
          })
        }
      }
    },
    
    // Tool execution hooks
    "tool.execute.before": async (input) => {
      if (currentSessionId) {
        await sendEvent({
          type: "session_update",
          session_id: currentSessionId,
          payload: {
            status: "processing",
            tool: input.tool,
          },
        })
      }
    },
    
    "tool.execute.after": async (input) => {
      if (currentSessionId) {
        await sendEvent({
          type: "tool_executed",
          session_id: currentSessionId,
          payload: {
            tool: input.tool,
            status: "completed",
          },
        })
      }
    },
  }
}
