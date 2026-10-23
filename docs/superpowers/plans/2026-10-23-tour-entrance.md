# Tour entrance implementation

1. Extract the existing SVG into a shared partial; add explicit playback and a
   completion event to the existing D2 animator, preserving login behavior.
2. Add a progressively enhanced entrance and chapter styling inside `/tour`.
3. Wire intro, skip, deep links, reduced motion and Turbo cleanup; retain all
   existing sample interactions.
4. Verify controller/brand/stylesheet regressions and browser behavior on desktop
   and at 320, 375, 414 and 768 px. Record status and handoff.
