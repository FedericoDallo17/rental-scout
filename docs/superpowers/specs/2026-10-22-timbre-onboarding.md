# Timbre first-search onboarding

Give accounts without saved searches a useful first experience: a branded welcome
with a direct first-search action, then three short steps (neighborhoods,
preferences, alerts/review). Existing accounts keep the regular search editor.
Saving uses the existing user-owned SearchPreference and redirect; completion
explains that phone/browser delivery still needs connecting. No automatic browser
permission prompts or deliveries. No migrations, dependencies or auth changes.

Use the approved Patio palette: verde #173F36, marfil #F4F0E6, amarillo #F2CA52,
fondo #F3F5EC, texto #17312A, secundario #56645B. Local Manrope, sentence case,
natural es-UY voseo and English. A quiet split layout pairs the task with a live
search summary; the existing door symbol anchors the welcome. Avoid a feature
carousel: the memorable moment is making a real search.

All steps remain usable without JavaScript. Enhanced flow supports back/next,
keyboard focus, progress, validation, neighborhood filtering and Turbo restoration.
Optional fields remain optional; no zones means the Montevideo location fallback.
Validation errors retain entered data. Welcome reappears if all searches are deleted.

QA inventory: empty welcome, each of three steps, changing zones/budget/currency,
back/forward retention, filtered and empty neighborhood results, validation recovery,
completion with and without alert eligibility, returning-account editor, English,
Spanish, mobile at 390/320px, no-JS form and Turbo back navigation.
