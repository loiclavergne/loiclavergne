# AGENTS.override.md
#
# Loic Engineer Portfolio
#
# Created by Loïc Lavergne on 25/03/2026
# Copyright © 2026 Loïc Lavergne. All rights reserved.
#

# Current Direction

The repository is in the middle of a 2026 rebuild from a legacy single-page
Bootstrap portfolio to a multi-page static site with bilingual routing.

Priority for the current implementation phase:
- establish the new source architecture
- generate English and French pages from shared renderers
- ship the Apple-like visual foundation and homepage storytelling
- keep placeholder states elegant where source content is not available yet

Current generator path:
- Swift package executable `SiteBuilder`
- JSON content resource bundled with the executable target

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
