# Bilingual User Interface Design

Each user owns a persisted `locale` (`en` or `es`), defaulting to English. An
authenticated header control updates the preference and subsequent requests run inside
`I18n.with_locale`. Locale is request-scoped, preventing leakage between concurrent
users. The signed-in product surfaces are translated first; unauthenticated Devise
pages remain in the default language because no user preference exists yet.
