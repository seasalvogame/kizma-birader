# Motion plans

Current commit at planning: `8682029`.

| Plan | Severity | Status | Dependency |
| --- | --- | --- | --- |
| [001 Reduced motion coverage](001-reduced-motion-coverage.md) | High | implemented; verification pending | none |
| [002 Shared duration scaling](002-shared-duration-scaling.md) | Medium | implemented; verification pending | 001 optional |
| [003 Reward and turn physicality](003-reward-and-turn-physicality.md) | Medium | implemented; verification pending | 002 |
| [004 Interruptible XP feedback](004-interruptible-xp-feedback.md) | Medium | implemented; verification pending | 002 |

Run motion checks with Reduce Motion both off and on; then use the normal and fast animation settings separately. No plan changes gameplay timing or server sequencing.
