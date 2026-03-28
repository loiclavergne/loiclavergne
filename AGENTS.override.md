# AGENTS.override.md
#
# Loic Engineer Portfolio
#
# Created by Loïc Lavergne on 25/03/2026
# Copyright © 2026 Loïc Lavergne. All rights reserved.
#

# Current Direction

The repository now runs on the Swift-generated bilingual static architecture.
The legacy single-page Bootstrap implementation has been retired from the
active codebase.

Priority for the current implementation phase:
- deepen content quality without expanding runtime complexity
- preserve Apple-like polish, restraint, and bilingual parity
- add deeper project storytelling through localized static detail pages
- keep placeholder states elegant where source content is not available yet
- avoid regressing into archived vendor or data-loading patterns

Current generator path:
- Swift package executable `SiteBuilder`
- split JSON resources bundled with the executable target

# Constraints To Respect

- Do not reintroduce Bootstrap or a heavy frontend framework.
- Do not move localization back into client-rendered JSON.
- Do not add external fonts or third-party trackers.
- Do not create runtime dependencies for features that can remain static.
- Do not silently remove French parity when changing English content.

# Follow-Up Gaps

The following sections are structurally ready but still need user-provided
content in a later pass:
- education
- books and yearly/monthly reading counts
- sports activities
- trophy case details
- final public contact email
