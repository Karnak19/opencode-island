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
      // Session created or updated - extract session info
      if (event.type === "session.created" || event.type === "session.updated") {
        const data = event.properties as { info?: { id?: string; title?: string } }
        if (data.info?.id) {
          const isNew = currentSessionId !== data.info.id
          currentSessionId = data.info.id
          
          // Only send session_start for new sessions
          if (isNew) {
            await sendEvent({
              type: "session_start",
              session_id: data.info.id,
              payload: {
                cwd: currentCwd,
                title: data.info.title || currentCwd?.split("/").pop(),
                model: "unknown",
              },
            })
          } else if (event.type === "session.updated" && data.info.title) {
            // Send session_update for title changes on existing sessions
            await sendEvent({
              type: "session_update",
              session_id: data.info.id,
              payload: {
                title: data.info.title,
              },
            })
          }
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
        const data = event.properties as { status?: { type?: string } | string }
        const status = typeof data.status === "object" ? data.status?.type : data.status
        if (status) {
          await sendEvent({
            type: "session_update",
            session_id: currentSessionId,
            payload: {
              status: status === "busy" ? "processing" : status,
            },
          })
        }
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
      
      // Permission request - this is the actual "waiting for approval" event
      if (event.type === "permission.updated" && currentSessionId) {
        const data = event.properties as {
          id?: string
          type?: string
          title?: string
          metadata?: { command?: string; tool?: string }
          callID?: string
        }
        // permission.updated means user needs to approve something
        await sendEvent({
          type: "session_update",
          session_id: currentSessionId,
          payload: {
            status: "waiting_for_approval",
            tool: data.metadata?.tool || data.type || "permission",
            permission_type: data.type,
            message: data.title,
          },
        })
      }
      
      // Permission replied - user approved or denied
      if (event.type === "permission.replied" && currentSessionId) {
        await sendEvent({
          type: "session_update",
          session_id: currentSessionId,
          payload: {
            status: "processing",
          },
        })
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
