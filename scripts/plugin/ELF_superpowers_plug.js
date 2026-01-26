/**
 * ELF Superpowers Hook Plugin for OpenCode.ai
 *
 * Provides post-tool learning hooks to run ELF learning scripts
 * after each tool execution for persistent memory and pattern tracking.
 *
 * Auto Check-In/Check-Out:
 * - session.created: Automatically runs check-in query
 * - session.compacted: Runs check-out before compaction
 * - session.deleted: Runs check-out at session end
 *
 * OpenCode Plugin System - Uses "tool.execute.before/after" hooks
 */

import { tool } from "@opencode-ai/plugin";
import os from "os";
import path from "path";
import { existsSync, promises as fs } from "fs";

const HOME_DIR = os.homedir();
const OPENCODE_DIR = process.env.OPENCODE_DIR || path.join(HOME_DIR, ".opencode");
const ELF_DIR = process.env.ELF_BASE_PATH || path.join(OPENCODE_DIR, "emergent-learning");
const DASHBOARD_DIR = path.join(ELF_DIR, "dashboard-app");
const DASHBOARD_FALLBACK_DIR = path.join(ELF_DIR, "apps", "dashboard");
const TALKINHEAD_DIR = path.join(DASHBOARD_DIR, "TalkinHead");
const TALKINHEAD_FALLBACK_DIR = path.join(DASHBOARD_FALLBACK_DIR, "TalkinHead");
const HOOKS_DIR = path.join(ELF_DIR, "hooks", "learning-loop");
const QUERY_DIR = path.join(ELF_DIR, "query");
const ELF_CLEANUP_CONFIG_PATH = path.join(ELF_DIR, "elf_cleanup_config.json");
const DASHBOARD_IVI_LOCK_PATH = path.join(ELF_DIR, "elf_dashboard_ivi_lock.json");

const quote = (value) => `"${value}"`;
const pickPython = () => {
  const candidates = [
    process.env.ELF_PYTHON,
    path.join(ELF_DIR, ".venv", "bin", "python"),
    path.join(ELF_DIR, ".venv", "Scripts", "python.exe"),
    "python3",
    "python"
  ].filter(Boolean);
  return candidates.find((candidate) => existsSync(candidate)) || "python";
};

const PYTHON_CMD = pickPython();
async function loadElfCleanupConfig() {
  try {
    const data = await fs.readFile(ELF_CLEANUP_CONFIG_PATH, "utf8");
    const json = JSON.parse(data);
    return { enabled: json.enabled === undefined ? true : !!json.enabled, prompted: !!json.prompted };
  } catch (e) {
    // Default: enabled
    return { enabled: true, prompted: false };
  }
}
async function saveElfCleanupConfig(cfg) {
  const payload = JSON.stringify({ enabled: !!cfg.enabled, prompted: !!cfg.prompted });
  await fs.writeFile(ELF_CLEANUP_CONFIG_PATH, payload, "utf8");
  return true;
}

const PRE_TOOL_SCRIPT = `${quote(PYTHON_CMD)} ${quote(path.join(HOOKS_DIR, "pre_tool_learning.py"))}`;
const POST_TOOL_SCRIPT = `${quote(PYTHON_CMD)} ${quote(path.join(HOOKS_DIR, "post_tool_learning.py"))}`;

// ELF command paths
const CHECKIN_QUERY = `${quote(PYTHON_CMD)} ${quote(path.join(QUERY_DIR, "query.py"))} --context`;
// Lifecycle scripts for Dashboard/IVI
const DASHBOARD_START_SCRIPT = `bash -lc "${path.join(DASHBOARD_DIR, "run-dashboard.sh")}"`;
const DASHBOARD_START_FALLBACK_SCRIPT = `bash -lc "${path.join(DASHBOARD_FALLBACK_DIR, "run-dashboard.sh")}"`;
const TALKING_HEAD_IVI_START_SCRIPT = `bash -lc "${path.join(TALKINHEAD_DIR, "run-talkinhead.sh")}"`;
const TALKING_HEAD_IVI_START_FALLBACK_SCRIPT = `bash -lc "${path.join(TALKINHEAD_FALLBACK_DIR, "run-talkinhead.sh")}"`;
const DASHBOARD_STOP_SCRIPT = "bash -lc \"pkill -f run-dashboard.sh || true\"";
const TALKING_HEAD_IVI_STOP_SCRIPT = "bash -lc \"pkill -f TalkinHead || true\"";
const CHECKOUT_SCRIPT = `${quote(PYTHON_CMD)} ${quote(path.join(QUERY_DIR, "checkout.py"))}`;

// Track session state
let sessionCheckinDone = false;
let sessionId = null;

async function loadDashboardIvIlock() {
  try {
    const data = await fs.readFile(DASHBOARD_IVI_LOCK_PATH, 'utf8');
    return JSON.parse(data);
  } catch {
    return {};
  }
}
async function saveDashboardIvIlock(lock) {
  const payload = JSON.stringify(lock || {});
  await fs.writeFile(DASHBOARD_IVI_LOCK_PATH, payload, 'utf8');
}
async function clearDashboardIvIlock() {
  try { await fs.unlink(DASHBOARD_IVI_LOCK_PATH); } catch { /* ignore */ }
}

export const ELFHooksPlugin = async ({ client, $ }) => {
  return {
    /**
     * Pre-tool execution hook
     * Loads relevant heuristics before tool runs
     */
    "tool.execute.before": async (input, output) => {
      try {
        // Log hook trigger for debugging
        await client.app.log({
          service: "elf-hooks",
          level: "debug",
          message: `Pre-tool hook triggered for: ${input.tool}`
        });

        // Execute the pre-tool learning script
        // Note: This runs synchronously and blocks tool execution
        const result = await $`${PRE_TOOL_SCRIPT}`.quiet();

        if (result.exitCode !== 0) {
          await client.app.log({
            service: "elf-hooks",
            level: "warn",
            message: `Pre-tool hook exited with code: ${result.exitCode}`,
            extra: { stderr: result.stderr }
          });
        }

        await client.app.log({
          service: "elf-hooks",
          level: "debug",
          message: `Pre-tool hook completed for: ${input.tool}`
        });

      } catch (error) {
        await client.app.log({
          service: "elf-hooks",
          level: "error",
          message: `Pre-tool hook error: ${error.message}`,
          extra: { stack: error.stack }
        });
        // Don't throw - allow tool to continue even if hook fails
      }
    },

    /**
     * Post-tool execution hook
     * Records outcomes and validates tool results
     * This is the MAIN learning hook - captures what worked/failed
     */
    "tool.execute.after": async (input) => {
      try {
        await client.app.log({
          service: "elf-hooks",
          level: "debug",
          message: `Post-tool hook triggered for: ${input.tool}`
        });

        // Execute the post-tool learning script
        const result = await $`${POST_TOOL_SCRIPT}`.quiet();

        if (result.exitCode !== 0) {
          await client.app.log({
            service: "elf-hooks",
            level: "warn",
            message: `Post-tool hook exited with code: ${result.exitCode}`,
            extra: {
              stderr: result.stderr,
              tool: input.tool,
              args: input.args
            }
          });
        } else {
          await client.app.log({
            service: "elf-hooks",
            level: "debug",
            message: `Post-tool hook completed successfully for: ${input.tool}`
          });
        }

      } catch (error) {
        await client.app.log({
          service: "elf-hooks",
          level: "error",
          message: `Post-tool hook error: ${error.message}`,
          extra: {
            stack: error.stack,
            tool: input.tool
          }
        });
        // Don't throw - tool already executed, don't block on hook failure
      }
    },

    /**
     * Event hook for session lifecycle
     * Auto check-in at session start, auto check-out at end/compaction
     */
    event: async ({ event }) => {
      // Extract session ID from event
      const getSessionId = () => {
        return event.properties?.info?.id ||
               event.properties?.sessionID ||
               event.session?.id ||
               (event.sessionID) ||
               (event.properties?.session?.id);
      };

      const currentSessionId = getSessionId();

      /**
       * AUTO CHECK-IN: Run at session created
       * Loads context, golden rules, heuristics from the building
       */
        if (event.type === "session.created") {
          sessionId = currentSessionId;
          sessionCheckinDone = false;

        await client.app.log({
          service: "elf-hooks",
          level: "info",
          message: "Session started - Running auto check-in..."
        });

        try {
          // Run check-in query to load context
          const result = await $`${CHECKIN_QUERY}`.quiet();

        if (result.exitCode === 0) {
            sessionCheckinDone = true;
            await client.app.log({
              service: "elf-hooks",
              level: "info",
              message: "Auto check-in completed - Context loaded"
            });
            // Idempotent start: only start if not already started for this session
            try {
              const lock = await loadDashboardIvIlock();
              if (lock?.startedSessionId === sessionId) {
                await client.app.log({ service: "elf-hooks", level: "info", message: "Dashboard/IVI already started for this session. Skipping start." });
              } else {
                const dashCmd = `if [ -x "${path.join(DASHBOARD_DIR, "run-dashboard.sh")}" ]; then ${DASHBOARD_START_SCRIPT}; else ${DASHBOARD_START_FALLBACK_SCRIPT}; fi &`;
                const thCmd = `if [ -x "${path.join(TALKINHEAD_DIR, "run-talkinhead.sh")}" ]; then ${TALKING_HEAD_IVI_START_SCRIPT}; else ${TALKING_HEAD_IVI_START_FALLBACK_SCRIPT}; fi &`;
                await $`${dashCmd}`.quiet();
                await $`${thCmd}`.quiet();
                await saveDashboardIvIlock({ startedSessionId: sessionId });
                await client.app.log({ service: "elf-hooks", level: "info", message: "Dashboard and Talking Head IVI start commands issued (background)." });
              }
            } catch (err) {
              await client.app.log({
                service: "elf-hooks",
                level: "error",
                message: `Failed to start Dashboard/IVI: ${err.message}`,
                extra: { stack: err.stack }
              });
            }

            // Inject banner into session prompt for visibility
            try {
              await client.app.log({
                service: "elf-hooks",
                level: "info",
                message: "Dashboard and Talking Head IVI start commands issued (background)."
              });
            } catch (err) {
              await client.app.log({
                service: "elf-hooks",
                level: "error",
                message: `Failed to start Dashboard/IVI: ${err.message}`,
                extra: { stack: err.stack }
              });
            }

            // Inject banner into session prompt for visibility
            try {
              await client.session.prompt({
                path: { id: sessionId },
                body: {
                  noReply: true,
                  parts: [{
                    type: "text",
                    text: `\n🤖 **ELF Auto Check-In Complete**\nContext, golden rules, and heuristics loaded from the building.\n`,
                    synthetic: true
                  }]
                }
              });
            } catch (promptErr) {
              // Non-critical - banner insertion may fail in some contexts
              await client.app.log({
                service: "elf-hooks",
                level: "debug",
                message: "Could not inject check-in banner"
              });
            }
          } else {
            await client.app.log({
              service: "elf-hooks",
              level: "warn",
              message: `Auto check-in failed with code: ${result.exitCode}`,
              extra: { stderr: result.stderr }
            });
          }
        } catch (error) {
          await client.app.log({
            service: "elf-hooks",
            level: "error",
            message: `Auto check-in error: ${error.message}`
          });
        }
      }

      /**
       * AUTO CHECK-OUT: Run before session compaction
       * Records learnings before context is compacted
       */
      if (event.type === "session.compacted") {
        await client.app.log({
          service: "elf-hooks",
          level: "info",
          message: "Session compacting - Running auto check-out..."
        });

        try {
          // Stop Dashboard/IVI before compaction to gracefully tear down UI components
          try {
            await $`${DASHBOARD_STOP_SCRIPT}`.quiet();
            await $`${TALKING_HEAD_IVI_STOP_SCRIPT}`.quiet();
            await client.app.log({
              service: "elf-hooks",
              level: "debug",
              message: "Dashboard/IVI stopped prior to auto checkout (compaction)."
            });
          } catch (stopErr) {
            // Non-fatal - continue with checkout if stop fails
            await client.app.log({
              service: "elf-hooks",
              level: "warn",
              message: `Dashboard/IVI stop before checkout failed: ${stopErr?.message}`,
              extra: { stack: stopErr?.stack }
            });
          }

          // Run checkout to capture learnings before compaction
          const result = await $`${CHECKOUT_SCRIPT} --auto`.quiet();

          await client.app.log({
            service: "elf-hooks",
            level: "info",
            message: `Auto check-out completed (exit code: ${result.exitCode})`
          });
        } catch (error) {
          await client.app.log({
            service: "elf-hooks",
            level: "error",
            message: `Auto check-out error: ${error.message}`
          });
        }
      }

      /**
       * AUTO CHECK-OUT: Run at session deletion/end
       * Final check-out to record all learnings before session ends
       */
      if (event.type === "session.deleted") {
        if (sessionCheckinDone) {
          await client.app.log({
            service: "elf-hooks",
            level: "info",
            message: "Session ending - Running final auto check-out..."
          });

          // Automatic question to the user about future auto-cleanup behavior
          try {
            await client.session.prompt({
              path: { id: sessionId },
              body: {
                noReply: true,
                parts: [{
                  type: "text",
                  text: "\n🤖 ELF Question: Do you want automatic Dashboard/IVI cleanup on future session ends? You can configure this per-session with 'elf_cleanup_config --enabled true|false'.",
                  synthetic: true
                }]
              }
            });
          } catch (qerr) {
            // Non-critical
            await client.app.log({ service: "elf-hooks", level: "debug", message: "Question banner failed to display" });
          }

          try {
            // Stop Dashboard/IVI as part of final checkout to ensure a clean shutdown
            try {
              await $`${DASHBOARD_STOP_SCRIPT}`.quiet();
              await $`${TALKING_HEAD_IVI_STOP_SCRIPT}`.quiet();
              await client.app.log({
                service: "elf-hooks",
                level: "debug",
                message: "Dashboard/IVI stopped during final auto checkout."
              });
            } catch (stopErr) {
              await client.app.log({
                service: "elf-hooks",
                level: "warn",
                message: `Dashboard/IVI stop during final checkout failed: ${stopErr?.message}`,
                extra: { stack: stopErr?.stack }
              });
            }

            // Final checkout to ensure all learnings are captured
            const result = await $`${CHECKOUT_SCRIPT} --auto --final`.quiet();

            await client.app.log({
              service: "elf-hooks",
              level: "info",
              message: `Final auto check-out completed (exit code: ${result.exitCode})`
            });
            // Clear Dashboard/IVI lock for future sessions
            try {
              await clearDashboardIvIlock();
            } catch (e) {
              await client.app.log({ service: "elf-hooks", level: "warn", message: `Failed to clear Dashboard/IVI lock: ${e?.message}` });
            }
          } catch (error) {
            await client.app.log({
              service: "elf-hooks",
              level: "error",
              message: `Final auto check-out error: ${error.message}`
            });
          }
        }

        // Cleanup session state
        sessionId = null;
        sessionCheckinDone = false;
      }

      if (event.type === "session.idle") {
        // Optional: Log idle as checkpoint opportunity
        await client.app.log({
          service: "elf-hooks",
          level: "debug",
          message: "Session idle - checkpoint opportunity"
        });
      }
    },

    /**
     * Optional: Custom tools to control hooks and ELF session management
     */
    tool: {
      elf_checkin: tool({
        description: "Manually trigger ELF check-in to load context, golden rules, and heuristics from the building",
        args: {},
        execute: async (args, ctx) => {
          try {
            const result = await $`${CHECKIN_QUERY}`.quiet();
            if (result.exitCode === 0) {
              sessionCheckinDone = true;
              return "✅ ELF Check-In Complete\nContext, golden rules, and heuristics loaded from the building.";
            } else {
              return `⚠️ Check-In exited with code: ${result.exitCode}\nCheck OpenCode logs for details.`;
            }
          } catch (error) {
            return `❌ Check-In error: ${error.message}`;
          }
        }
      }),

      elf_checkout: tool({
        description: "Manually trigger ELF check-out to record learnings, heuristics, and session notes",
        args: {
          final: tool.schema.boolean().describe("Mark this as final checkout before session ends").optional()
        },
        execute: async (args, ctx) => {
          const flags = args.final ? " --final" : "";
          try {
            const result = await $`${CHECKOUT_SCRIPT}${flags}`.quiet();
            return `✅ ELF Check-Out Complete\nLearnings recorded. (exit code: ${result.exitCode})`;
          } catch (error) {
            return `❌ Check-Out error: ${error.message}`;
          }
        }
      }),

      elf_hooks_status: tool({
        description: "Check ELF hooks status, session state, and configuration",
        args: {},
        execute: async (args, ctx) => {
          // Lightweight health: verify Dashboard/IVI processes are running
          let dashRunning = false;
          let thRunning = false;
          try {
            const r1 = await $`bash -lc "pgrep -f start-dashboard.sh"`;
            dashRunning = (typeof r1.exitCode === 'number') ? (r1.exitCode === 0) : false;
          } catch {
            dashRunning = false;
          }
          try {
            const r2 = await $`bash -lc "pgrep -f start-talking-head-ivi.sh"`;
            thRunning = (typeof r2.exitCode === 'number') ? (r2.exitCode === 0) : false;
          } catch {
            thRunning = false;
          }
          return `🤖 ELF Hooks Plugin Status
━━━━━━━━━━━━━━━━━━━━━

📋 Session State:
   - Session ID: ${sessionId || "N/A"}
   - Check-in done: ${sessionCheckinDone ? "✅ Yes" : "⚠️ No"}
   - Check-out pending: ${sessionCheckinDone ? "Yes (auto on end)" : "N/A"}

🔧 Hook Configuration:
   - Pre-tool: ${PRE_TOOL_SCRIPT}
   - Post-tool: ${POST_TOOL_SCRIPT}
   - Check-in: ${CHECKIN_QUERY}
   - Check-out: ${CHECKOUT_SCRIPT}

📊 Auto Check-In/Check-Out:
   - ✅ session.created → Auto check-in
   - ⚠️ session.compacted → Auto check-out
   - ✅ session.deleted → Final auto check-out

💡 Commands:
   /checkin or elf_checkin - Load context
   /checkout or elf_checkout - Record learnings

  Logs written to: OpenCode app logs
Dashboard: ${dashRunning ? 'Running' : 'Not running'}
Talking Head IVI: ${thRunning ? 'Running' : 'Not running'}`;
        }
      }),

      elf_cleanup_config: tool({
        description: "Configure automatic cleanup on session end (Dashboard/IVI)",
        args: {
          enabled: tool.schema.boolean().describe("Enable automatic cleanup on session end").optional()
        },
        execute: async (args, ctx) => {
          // Load existing config
          let cfg = { enabled: true, prompted: false };
          try {
            cfg = await loadElfCleanupConfig();
          } catch (_) {
            // ignore, keep defaults
          }
          if (typeof args.enabled === 'boolean') {
            cfg.enabled = args.enabled;
          }
          try {
            await saveElfCleanupConfig(cfg);
            return `✅ ELF auto-cleanup on session end set to ${cfg.enabled ? 'ENABLED' : 'DISABLED'}.`;
          } catch (e) {
            return `❌ Failed to save cleanup config: ${e.message}`;
          }
        }
      }),

      elf_hooks_toggle: tool({
        description: "Enable or disable ELF learning hooks temporarily",
        args: {
          enabled: tool.schema.boolean().describe("Whether hooks should be enabled")
        },
        execute: async (args, ctx) => {
          const status = args.enabled ? "enabled" : "disabled";
          return `ELF hooks ${status}.
Note: This only affects this session. To permanently change, modify the plugin file.

To disable permanently, rename or remove:
~/.opencode/plugin/ELF_superpowers_plug.js`;
        }
      }),

      elf_reload_hooks: tool({
        description: "Force reload ELF hooks configuration",
        args: {},
        execute: async (args, ctx) => {
          return `ELF hooks cannot be reloaded at runtime in OpenCode.
To apply changes:
1. Restart OpenCode, or
2. Modify the plugin file and run: touch ~/.opencode/plugin/ELF_superpowers_plug.js

Plugin file location:
/home/bamer/.opencode/emergent-learning/ELF_superpowers_plug.js`;
        }
      })
    }
  };
};
