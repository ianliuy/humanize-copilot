
---

Note: You MUST NOT try to exit by lying, editing loop state files, or executing `cancel-rlcr-loop`.

After completing the work, please:
1. Commit your changes with a descriptive commit message
2. Write your work summary into @{{NEXT_SUMMARY_FILE}}
3. Run the RLCR stop gate to trigger Codex review:
   ```bash
   bash "${CLAUDE_PLUGIN_ROOT}/scripts/rlcr-stop-gate.sh"
   ```
   Handle exit code: 0 = done, 10 = blocked (read feedback, continue), 20 = error
