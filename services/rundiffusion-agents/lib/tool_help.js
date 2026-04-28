"use strict";

function buildBrowserControlsSection() {
  return {
    title: "Browser controls",
    tips: [
      "Press F6 to toggle mouse capture on or off so you can switch between terminal interaction and browser-style scrolling.",
      "On Mac, hold Option while selecting text to copy it from the browser terminal.",
      "On Windows, hold Shift while selecting text to copy it from the browser terminal.",
    ],
  };
}

function buildDirectorySection(title, description, directories) {
  return {
    title,
    description,
    directories,
  };
}

function buildCommand(label, command, description) {
  return { label, command, description };
}

function buildCliWorkspaceHelp({ toolLabel, workspaceDir, relaunchCommand, shortcutDirectories = [] }) {
  const sections = [
    buildBrowserControlsSection(),
    {
      title: "Session flow",
      description: `${toolLabel} opens inside its own managed terminal session.`,
      tips: [
        `Exiting ${toolLabel} drops you back into the shell in ${workspaceDir}.`,
        "Run `ls` to inspect the current directory before switching contexts.",
        "Use `cd <path>` to move into a different workspace before starting another CLI tool.",
      ],
      commands: [buildCommand(`Relaunch ${toolLabel}`, relaunchCommand, `Starts ${toolLabel} again from the current shell.`)],
    },
    buildDirectorySection("Common directories", "These are the main workspaces available inside this deployment.", [
      workspaceDir,
      "/data/workspaces/openclaw",
      "/data/workspaces/hermes",
    ]),
  ];

  if (shortcutDirectories.length > 0) {
    sections.push(
      buildDirectorySection(
        "Shortcut directories",
        "These shortcuts are created inside the tool workspace so you can jump into the shared project folders quickly.",
        shortcutDirectories,
      ),
    );
  }

  return {
    title: `${toolLabel} helper`,
    description: `Quick reference for moving around the ${toolLabel} terminal, relaunching the CLI, and copying the exact commands you need.`,
    sections,
  };
}

function buildToolHelp() {
  return {
    openclaw: {
      title: "OpenClaw helper",
      description: "Use OpenClaw for the primary control UI, then keep this shortcut nearby when you want to change models quickly.",
      sections: [
        {
          title: "Model switching",
          tips: [
            "Run this directly inside the OpenClaw prompt to swap the active model without leaving the interface.",
          ],
          commands: [
            buildCommand(
              "Switch to GPT-5.4",
              "/model openai-codex/gpt-5.4",
              "Copies the raw OpenClaw model-switch command.",
            ),
          ],
        },
      ],
    },
    terminal: {
      title: "Terminal helper",
      description: "This shell is the maintenance front door for the deployment. Use it to move between workspaces, authenticate tools, and relaunch AI CLIs after exiting them.",
      sections: [
        buildBrowserControlsSection(),
        {
          title: "Shell basics",
          tips: [
            "Run `ls` to inspect the current directory before changing workspaces.",
            "Use `cd <path>` to move between the OpenClaw, Hermes, Codex, Claude, Gemini CLI, and Pi workspaces.",
            "After exiting a CLI tool, relaunch it from the shell with its command name.",
          ],
          commands: [
            buildCommand(
              "OpenClaw auth login",
              "openclaw models auth login --provider openai-codex --set-default",
              "Authenticates OpenClaw against the OpenAI Codex provider and makes it the default.",
            ),
          ],
        },
        buildDirectorySection("Common directories", "Jump into any workspace with `cd <path>`.", [
          "/data/workspaces/openclaw",
          "/data/workspaces/hermes",
          "/data/workspaces/codex",
          "/data/workspaces/claude",
          "/data/workspaces/gemini",
          "/data/workspaces/pi",
        ]),
        {
          title: "Launch an AI CLI from the shell",
          tips: [
            "Each command below can be run after you exit back to the shell and move into the directory you want to work in.",
          ],
          commands: [
            buildCommand("Start Codex", "codex", "Launches the Codex CLI from the current shell."),
            buildCommand("Start Claude Code", "claude", "Launches Claude Code from the current shell."),
            buildCommand("Start Gemini CLI", "gemini", "Launches Gemini CLI from the current shell."),
            buildCommand("Start Pi", "pi", "Launches Pi from the current shell."),
          ],
        },
      ],
    },
    hermes: {
      title: "Hermes CLI helper",
      description: "Hermes starts inside its own terminal session and falls back to a shell when you exit, so you can move around and relaunch it without leaving the route.",
      sections: [
        buildBrowserControlsSection(),
        {
          title: "Model switching",
          tips: [
            "Run this directly in Hermes when you want to move the session over to GPT-5.4.",
          ],
          commands: [
            buildCommand(
              "Switch to GPT-5.4",
              "/model openai-codex/gpt-5.4",
              "Copies the raw Hermes model-switch command.",
            ),
          ],
        },
        {
          title: "Session flow",
          tips: [
            "Exiting Hermes returns you to the shell in `/data/workspaces/hermes`.",
            "Use `ls` to inspect the folder and `cd <path>` to move into another workspace before relaunching Hermes or another tool.",
          ],
          commands: [buildCommand("Relaunch Hermes", "hermes", "Starts Hermes again from the current shell.")],
        },
        buildDirectorySection("Common directories", "Use these paths when switching between workspaces.", [
          "/data/workspaces/hermes",
          "/data/workspaces/openclaw",
          "/data/workspaces/codex",
        ]),
      ],
    },
    hermesWebui: {
      title: "Hermes WebUI helper",
      description: "Hermes WebUI uses the same Hermes home and workspace as the terminal route, but gives you sessions, tasks, memory, skills, and files in a browser-native interface.",
      sections: [
        {
          title: "Shared state",
          tips: [
            "The WebUI reads and writes `/data/.hermes` for Hermes state.",
            "The default workspace is `/data/workspaces/hermes`.",
            "Use the Hermes terminal if you need the raw CLI in the same workspace.",
          ],
        },
        buildDirectorySection("Common directories", "These paths are shared with the dedicated Hermes terminal.", [
          "/data/.hermes",
          "/data/.hermes/webui",
          "/data/workspaces/hermes",
        ]),
      ],
    },
    codex: buildCliWorkspaceHelp({
      toolLabel: "Codex",
      workspaceDir: "/data/workspaces/codex",
      relaunchCommand: "codex",
      shortcutDirectories: ["openclaw-workspace", "hermes-workspace"],
    }),
    claude: buildCliWorkspaceHelp({
      toolLabel: "Claude Code",
      workspaceDir: "/data/workspaces/claude",
      relaunchCommand: "claude",
      shortcutDirectories: ["openclaw-workspace", "hermes-workspace"],
    }),
    gemini: buildCliWorkspaceHelp({
      toolLabel: "Gemini CLI",
      workspaceDir: "/data/workspaces/gemini",
      relaunchCommand: "gemini",
      shortcutDirectories: ["openclaw-workspace", "hermes-workspace"],
    }),
    pi: buildCliWorkspaceHelp({
      toolLabel: "Pi",
      workspaceDir: "/data/workspaces/pi",
      relaunchCommand: "pi",
      shortcutDirectories: ["openclaw-workspace", "hermes-workspace"],
    }),
  };
}

module.exports = {
  buildToolHelp,
};
