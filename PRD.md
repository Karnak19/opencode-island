# Product Requirements Document: Opencode Island

**Version:** 1.0  
**Date:** December 24, 2025  
**Author:** Basile  
**Status:** Draft

---

## Executive Summary

Opencode Island is a native macOS menu bar application that brings Dynamic Island-style notifications to OpenCode CLI sessions. It eliminates context switching by providing real-time session monitoring, tool execution approvals, and chat history viewing directly from the MacBook notch area.

**Target Users:** Developers using OpenCode for AI-assisted coding  
**Platform:** macOS 15.6+  
**Distribution:** Single `.app` download, zero-configuration setup

---

## 1. Product Vision

### 1.1 Problem Statement

Developers using OpenCode CLI currently face several friction points:

- **Context Switching:** Must switch from IDE/browser to terminal to approve tool executions
- **Lost Visibility:** No awareness of OpenCode activity when terminal is minimized/hidden
- **Session Management:** Difficult to track multiple concurrent OpenCode sessions
- **Approval Delays:** Interruptions to workflow when tool permissions are needed
- **History Access:** Can't quickly review chat history without scrolling terminal

### 1.2 Solution

A native macOS menu bar app that provides ambient awareness and quick-action controls for OpenCode sessions through an elegant Dynamic Island-inspired interface.

---

## 2. User Personas

### Primary Persona: "Alex - The Full-Stack Developer"

- **Background:** 5+ years experience, uses OpenCode for rapid prototyping
- **Pain Points:** Loses flow state when switching to terminal for approvals
- **Goals:** Stay focused in IDE while maintaining control over AI actions
- **Tech Setup:** MacBook Pro with notch, multiple monitors

### Secondary Persona: "Jordan - The DevOps Engineer"

- **Background:** Manages infrastructure, runs multiple OpenCode sessions
- **Pain Points:** Needs to track several concurrent automation tasks
- **Goals:** Monitor all sessions at a glance, intervene when needed
- **Tech Setup:** MacBook Air, often works remotely

---

## 3. Core Features

### 3.1 Automatic Installation & Setup

**User Story:** As a new user, I want zero-configuration setup so I can start using the app immediately.

**Requirements:**
- ✅ **FR-001:** App detects OpenCode installation on first launch
- ✅ **FR-002:** Auto-installs plugin to `~/.opencode/plugin/opencode-island.ts`
- ✅ **FR-003:** Validates plugin installation and shows success/error state
- ✅ **FR-004:** Provides manual installation instructions if auto-install fails
- ✅ **FR-005:** Starts Unix socket server at `~/.opencode-island/socket`
- ✅ **FR-006:** Optionally adds app to Login Items for launch at startup

**Acceptance Criteria:**
- New user can download `.app`, drag to Applications, launch, and have it working within 30 seconds
- If OpenCode not installed, clear error message with link to OpenCode installation docs
- Socket path conflicts are detected and resolved automatically

---

### 3.2 Dynamic Island-Style Notifications

**User Story:** As a developer, I want subtle, non-intrusive notifications so I stay aware without being distracted.

**Requirements:**
- ✅ **FR-007:** Animated overlay expands from MacBook notch area
- ✅ **FR-008:** Displays active OpenCode session count in collapsed state
- ✅ **FR-009:** Shows current activity status (idle, thinking, executing)
- ✅ **FR-010:** Supports custom notification sounds (on/off toggle)
- ✅ **FR-011:** Respects macOS Do Not Disturb mode
- ✅ **FR-012:** Auto-collapses after 5 seconds of inactivity (configurable)

**Visual States:**
- **Collapsed:** Small pill showing session count badge
- **Compact:** Brief notification with session name and status
- **Expanded:** Full notification with action buttons

**Acceptance Criteria:**
- Animations are smooth (60fps) and respect system-level reduce motion settings
- Notch overlay doesn't interfere with existing notch interactions (camera, Control Center)
- Works gracefully on Macs without notch (falls back to menu bar icon)

---

### 3.3 Live Session Monitoring

**User Story:** As a user with multiple projects, I want to track all OpenCode sessions in one place.

**Requirements:**
- ✅ **FR-013:** Lists all active OpenCode sessions in real-time
- ✅ **FR-014:** Shows session metadata (directory, model, duration)
- ✅ **FR-015:** Displays current session status (idle, working, waiting for approval)
- ✅ **FR-016:** Provides session-specific actions (view history, terminate)
- ✅ **FR-017:** Auto-removes terminated sessions from list
- ✅ **FR-018:** Persists session history for recently closed sessions (last 10)

**Session Card Information:**
```
📁 Project Name
🤖 Model: claude-sonnet-4.5
⏱️ Duration: 12m 34s
📊 Status: Waiting for approval
```

**Acceptance Criteria:**
- Session list updates within 500ms of OpenCode state changes
- Clicking session opens detailed view
- Session list supports search/filter (stretch goal)

---

### 3.4 Tool Execution Approvals

**User Story:** As a developer, I want to approve/deny tool executions without leaving my current workspace.

**Requirements:**
- ✅ **FR-019:** Notch expands when tool approval is needed
- ✅ **FR-020:** Displays tool name and arguments clearly
- ✅ **FR-021:** Provides "Approve" and "Deny" buttons
- ✅ **FR-022:** Shows preview of tool action (e.g., file to be modified)
- ✅ **FR-023:** Supports keyboard shortcuts (⌘+Return to approve, ⌘+Delete to deny)
- ✅ **FR-024:** Remembers approval preferences per tool type (optional)
- ✅ **FR-025:** Timeout after 60 seconds, auto-deny with notification

**Approval UI Example:**
```
┌────────────────────────────────────────┐
│ OpenCode wants to run:                 │
│                                        │
│ Tool: write                            │
│ File: src/components/Button.tsx       │
│ Action: Create new file                │
│                                        │
│  [Deny]              [Approve ✓]      │
└────────────────────────────────────────┘
```

**Acceptance Criteria:**
- Tool approval request appears within 1 second of OpenCode triggering event
- Buttons are large enough for easy clicking (44pt touch targets)
- Preview truncates long arguments intelligently
- Approval/denial response sent back to OpenCode within 200ms

---

### 3.5 Chat History Viewer

**User Story:** As a developer, I want to review conversation history without scrolling through terminal output.

**Requirements:**
- ✅ **FR-026:** Opens popover window from notch/menu bar
- ✅ **FR-027:** Renders markdown formatting correctly
- ✅ **FR-028:** Syntax highlights code blocks
- ✅ **FR-029:** Shows user messages and AI responses chronologically
- ✅ **FR-030:** Supports copy-to-clipboard for individual messages
- ✅ **FR-031:** Displays message timestamps
- ✅ **FR-032:** Auto-scrolls to latest message
- ✅ **FR-033:** Search within conversation (stretch goal)

**Acceptance Criteria:**
- History loads within 500ms for sessions with <100 messages
- Markdown rendering matches GitHub/OpenCode styling
- Popover doesn't block critical screen areas
- History persists across app restarts

---

### 3.6 Settings & Preferences

**User Story:** As a power user, I want to customize app behavior to match my workflow.

**Requirements:**
- ✅ **FR-034:** Notification preferences (sounds, duration, position)
- ✅ **FR-035:** Keyboard shortcut customization
- ✅ **FR-036:** Launch at login toggle
- ✅ **FR-037:** Default approval behavior per tool type
- ✅ **FR-038:** Theme selection (auto/light/dark)
- ✅ **FR-039:** Socket path configuration (advanced)
- ✅ **FR-040:** Reset to defaults option

**Acceptance Criteria:**
- Settings persist across app restarts
- Invalid configurations show helpful error messages
- Settings changes take effect immediately (no restart required)

---

## 4. Technical Architecture

### 4.1 System Components

```
┌─────────────────────────────────────┐
│  Opencode Island.app                │
│  ┌───────────────────────────────┐  │
│  │  Swift/SwiftUI Menu Bar App   │  │
│  │  - Dynamic Island UI          │  │
│  │  - Settings Management        │  │
│  │  - Unix Socket Server         │  │
│  └───────────────────────────────┘  │
│                                     │
│  Embedded Resources:                │
│  - opencode-island.ts (plugin)      │
│  - Installation scripts             │
└─────────────────────────────────────┘
         ↕ Unix Socket IPC
┌─────────────────────────────────────┐
│  OpenCode Process                   │
│  ┌───────────────────────────────┐  │
│  │  Plugin System                │  │
│  │  ~/.opencode/plugin/          │  │
│  │    opencode-island.ts         │  │
│  │                               │  │
│  │  - Event listeners (32+)      │  │
│  │  - JSON serialization         │  │
│  │  - Socket client              │  │
│  └───────────────────────────────┘  │
└─────────────────────────────────────┘
```

### 4.2 Communication Protocol

**Socket Message Format:**
```json
{
  "version": "1.0",
  "type": "tool_approval_needed" | "event" | "session_update",
  "timestamp": 1735059600000,
  "session_id": "ses_abc123",
  "payload": {
    "tool": "write",
    "args": { "path": "file.ts", "content": "..." }
  }
}
```

### 4.3 Plugin Events Monitored

**High Priority:**
- `tool.execute.before` - Tool approval requests
- `tool.execute.after` - Tool completion
- `session.created` - New session started
- `session.idle` - Session waiting
- `session.error` - Error occurred

**Medium Priority:**
- `message.part.updated` - AI response streaming
- `file.edited` - File modifications
- `permission.replied` - Permission granted/denied

**Low Priority (Stretch):**
- `session.status` - General status updates
- `tui.prompt.append` - User input

### 4.4 Data Persistence

**Storage Locations:**
- App Settings: `~/Library/Preferences/com.opencodeisland.plist`
- Socket Path: `~/.opencode-island/socket`
- Plugin Location: `~/.opencode/plugin/opencode-island.ts`
- Session History: In-memory only (no disk persistence for privacy)

### 4.5 Technology Stack

**macOS App:**
- Language: Swift 6.0+
- UI Framework: SwiftUI
- Minimum OS: macOS 15.6 (Sequoia)
- Build Tool: Xcode 16+
- Distribution: Direct download, GitHub Releases

**Plugin:**
- Language: TypeScript 5.0+
- Runtime: Executed by OpenCode (Bun/Node.js)
- Dependencies: `@opencode-ai/plugin`, `net` (Node.js built-in)

---

## 5. User Experience Flow

### 5.1 First Launch Flow

```
1. User downloads Opencode Island.dmg
2. User drags app to Applications folder
3. User launches Opencode Island
4. App checks for OpenCode installation
   ├─ If found: Continue to step 5
   └─ If not found: Show "OpenCode Not Detected" dialog
       └─ Provide link to opencode.ai installation docs
5. App checks for plugin installation
   ├─ If exists: Skip to step 7
   └─ If not exists: Continue to step 6
6. App copies plugin to ~/.opencode/plugin/opencode-island.ts
   └─ Show "Installation Successful" notification
7. App starts Unix socket server
8. Menu bar icon appears
9. Welcome dialog shows:
   - ✓ Plugin installed
   - ✓ Socket server running
   - ⚙️ Open Settings
   - ℹ️ View Tutorial
10. User clicks "Get Started"
11. App ready for use
```

### 5.2 Daily Usage Flow

```
1. OpenCode session starts in terminal
2. Plugin detects session.created event
3. Menu bar icon updates (badge shows "1")
4. User continues working in IDE
5. OpenCode wants to write a file
6. Plugin sends tool_approval_needed event
7. Notch animates outward
8. Shows: "Write to src/App.tsx"
9. User clicks "Approve"
10. Notch collapses
11. OpenCode writes file
12. Plugin sends tool_completed event
13. Notch briefly shows "✓ File written"
14. Returns to idle state
```

---

## 6. Non-Functional Requirements

### 6.1 Performance

- **NFR-001:** App launch time < 2 seconds
- **NFR-002:** Event processing latency < 200ms
- **NFR-003:** Memory footprint < 50MB idle, < 150MB active
- **NFR-004:** CPU usage < 5% idle, < 15% during animations
- **NFR-005:** Socket connection retry on failure (max 5 attempts)

### 6.2 Reliability

- **NFR-006:** Graceful degradation if OpenCode terminates
- **NFR-007:** Auto-recovery from socket disconnections
- **NFR-008:** No data loss during app crashes
- **NFR-009:** Handles malformed JSON from plugin gracefully

### 6.3 Security

- **NFR-010:** Unix socket has restrictive permissions (600)
- **NFR-011:** No sensitive data logged to system logs
- **NFR-012:** Plugin cannot execute arbitrary code outside OpenCode
- **NFR-013:** All IPC communication is local-only (no network)

### 6.4 Accessibility

- **NFR-014:** Full VoiceOver support
- **NFR-015:** Keyboard navigation for all actions
- **NFR-016:** Respects system accessibility settings (reduce motion, contrast)
- **NFR-017:** Text minimum size follows system preferences

### 6.5 Privacy

- **NFR-018:** No telemetry
- **NFR-019:** Chat history never leaves device
- **NFR-020:** No data collection or transmission

---

## 7. Release Strategy

### 7.1 MVP (v1.0)

**Must Have:**
- ✅ Automatic plugin installation
- ✅ Tool approval notifications
- ✅ Session monitoring (basic)
- ✅ Menu bar icon with badge
- ✅ Settings (minimal)

**Can Skip:**
- Chat history viewer (v1.1)
- Advanced settings

### 7.2 V1.1

**Features:**
- ✅ Full chat history viewer
- ✅ Markdown rendering
- ✅ Search within history
- ✅ Keyboard shortcuts customization

### 7.3 V1.2

**Features:**
- ✅ Auto-update system
- ✅ Advanced preferences
- ✅ Multi-session management improvements

---

## 8. Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| OpenCode plugin API changes | High | Medium | Pin to specific OpenCode version, monitor changelog |
| MacOS API deprecation | Medium | Low | Use stable SwiftUI APIs, avoid deprecated functions |
| Socket performance issues | Medium | Medium | Implement connection pooling, rate limiting |
| Low adoption | High | Medium | Create demo video, write detailed blog post |
| Notch compatibility issues | Low | Low | Fallback to standard menu bar on incompatible Macs |

---

## 9. Open Questions

1. **Q:** Should we support Macs without notch?  
   **A:** Yes, graceful fallback to menu bar icon + popover

2. **Q:** How to handle very long tool arguments?  
   **A:** Truncate with "Show More" button in approval UI

3. **Q:** Should we persist chat history to disk?  
   **A:** No for v1.0 (privacy), maybe opt-in for v1.2

4. **Q:** Internationalization?  
   **A:** English only for v1.0, i18n infrastructure for v1.1

---

## 10. Out of Scope (Future Considerations)

- ❌ Windows/Linux support
- ❌ OpenCode Desktop integration
- ❌ Cloud sync of settings
- ❌ Collaboration features (share sessions)
- ❌ AI-powered suggestions
- ❌ Integration with other AI coding tools
- ❌ Browser extension companion

---

## Appendix A: Competitive Analysis

| Feature | Claude Island | Opencode Island | Advantage |
|---------|---------------|-----------------|-----------|
| Dynamic Island UI | ✅ | ✅ | Parity |
| Tool Approvals | ✅ | ✅ | Parity |
| Session Monitoring | ✅ | ✅ | Parity |
| Chat History | ✅ | ✅ (v1.1) | Behind |
| Event Count | 4 hooks | 32+ events | **Ahead** |
| Plugin System | Shell scripts | Native plugins | **Ahead** |
| Type Safety | ❌ | ✅ | **Ahead** |
| Auto-install | ✅ | ✅ | Parity |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-24 | Basile | Initial draft |
| 1.1 | 2025-12-25 | Basile | Updated for solo project, removed metrics/analytics |
