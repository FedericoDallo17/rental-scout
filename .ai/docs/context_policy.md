# Context Policy

- Keep structure simple.
- Use the Rails monorepo as the default architecture.
- Treat the portal as the primary user-facing surface.
- Treat the scraper/job pipeline as the primary backend engine.
- Read only the docs and files needed for the current ticket.
- Prefer official `.ai` docs, summaries, and tickets over old chat history.
- Keep Context Packs short, explicit, and ticket-specific.
- Include scraper/job assumptions, provider boundaries, and notification idempotency notes when relevant.
