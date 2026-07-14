# AI Limit Notch 0.1.3

This update improves the Notch layout and makes provider usage refresh more reliable.

- Set the mini Notch to 184 × 30 px with adjusted top spacing and a solid black background
- Size the expanded Notch automatically from its live content
- Replace missing mini values with an animated loading indicator
- Preserve valid Claude Code limit windows until their official reset time
- Add an optional zero-model-cost Claude `/usage` refresh with a 30-minute cooldown
- Show Codex weekly usage only, including in the mini Notch
- Prevent overlapping usage refreshes and stale provider values

The app is signed with an Apple Development certificate but is not notarized with Developer ID. macOS may ask you to allow it from **System Settings › Privacy & Security** on first launch.
