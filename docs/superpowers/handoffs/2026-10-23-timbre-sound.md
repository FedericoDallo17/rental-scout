# Click-triggered Timbre sound

Added a quiet synthesized E5/C5 ding-dong to explicit tour activation and the
brand replay button. The audio context is created inside the user gesture; no
audio assets, libraries or permission prompts. Each note has three decaying sine
partials. Automatic brand playback and skip stay silent. Sound also works when
reduced motion bypasses the visual animation. Contexts close on completion,
subsequent activation, pagehide and Turbo cache; audio failure cannot block entry.

Validation: both JS syntax checks and git diff --check passed. A transient Node
Web Audio mock check verified lazy creation, two-note pitch/timing, completion
and navigation cleanup, unavailable API and rejected resume. Full Rails suite:
327 tests, 2074 assertions, no failures. Actual speaker playback was not audited.

Sound changes are isolated for publication on main; production deployment is a
separate step. Existing deployment/domain edits and other untracked work were preserved.
