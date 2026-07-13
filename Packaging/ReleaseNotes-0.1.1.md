# AI Limit Notch 0.1.1

This update removes all placeholder usage values so the Notch only presents limits read from local provider data.

- Show only live Claude Code and Codex rate-limit metrics
- Remove mock session, weekly, Fable, and unsupported-provider values
- Display an em dash in the mini Notch when a live 5-hour limit is unavailable
- Display a clear no-data state when a provider cannot be read
- Clear stale provider values after a failed refresh
- Continue refreshing local provider data every 20 seconds

The app is signed with an Apple Development certificate but is not notarized with Developer ID. macOS may ask you to allow it from **System Settings › Privacy & Security** on first launch.
