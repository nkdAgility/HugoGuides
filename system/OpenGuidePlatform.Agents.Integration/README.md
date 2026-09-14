# Agent integration

Distributed integration assets for Codex, Claude and GitHub Copilot. This component owns skills, agent definitions, client workflows/commands, hooks, shared instructions and configuration templates as they are implemented.

Current contents:

- `skills/`: the seven publishing skills, usage instructions, license and provenance. Installation places these in the consumer's `.agents/skills/` directory.
- `instructions/guide-site.md`: canonical distributed contributor instructions. Installation uses these for `.agents/agents.md`, the root instruction symlinks and Copilot instructions.

Future agent definitions, Claude workflows/commands, client hook adapters and configuration templates belong here in clearly named directories. They are not implemented or enabled by this rename.

Executable validation belongs in `OpenGuidePlatform.PowerShell.AgentControls`. Hooks must be thin calls to those PowerShell operations. Skills and workflows call the appropriate publishing/build module rather than duplicate its implementation. Consumer configuration remains reviewed through installation/update; adding this component does not change agent permissions.
