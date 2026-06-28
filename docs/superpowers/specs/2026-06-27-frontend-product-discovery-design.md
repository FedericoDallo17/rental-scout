# Rental Scout Lite Frontend Product Discovery Design

## Context
Rental Scout Lite already has a minimal working portal that shows persisted scraped listings. The next step is not a technical rewrite but a product-facing frontend direction. The user wants the experience to feel polished and premium, with an Airbnb-like consumer tone, while preserving the real product structure: the user creates searches, the scraper updates results automatically, and each user ends up with a customized apartment feed.

This means the frontend should not be designed as a generic listings site or a temporary search-results page. It should be designed as a personalized apartment marketplace organized around saved searches.

## Product Framing
The core frontend promise is:

**"Come back here and see the apartment opportunities your saved searches have found for you."**

The user does not primarily arrive to manually search from scratch each time. Instead:
- the user creates one or more searches
- the system keeps scraping in the background
- each search becomes a living feed
- the frontend becomes the place to browse those updated results

This is closer to a personal scouting assistant expressed through a marketplace UI than to a traditional rental portal.

## Goals
- Make the frontend feel premium and consumer-friendly.
- Preserve a marketplace-first browsing experience.
- Center the UX around saved searches.
- Make the selected search feel like the active browsing context.
- Keep listing discovery easy to scan and revisit repeatedly.

## Non-Goals
- Designing an admin dashboard.
- Designing debugging or scraper-observability screens as the main experience.
- Building advanced analytics, real-time live updates, or dense operations UI.
- Designing full search-builder workflows in this phase.
- Replacing the marketplace feel with a tool-heavy enterprise layout.

## Approaches Considered

### 1. Marketplace-first personalized search UI
**Recommendation.**

Pros:
- Best matches the desired Airbnb-like feel.
- Keeps the page browseable and visually attractive.
- Lets saved searches shape the experience without overwhelming it.
- Supports repeat visitation naturally: open app, choose search, browse feed.

Cons:
- Less operational detail visible on the first screen.
- Some system state like run health or notification history is deferred.

### 2. Tool-first workspace UI
Pros:
- Stronger for power-user workflows.
- Easier to surface search metadata, filters, and system status.

Cons:
- Feels less premium and less consumer-facing.
- Risks pushing the product toward dashboard complexity too early.

### 3. Editorial premium discovery UI
Pros:
- Can feel highly polished and branded.
- Strong for visual delight.

Cons:
- Weaker for efficient apartment scanning.
- Risks hiding the practical value of saved-search feeds.

## Decision
Use a **marketplace-first UI with personalized saved-search navigation**.

The homepage should feel like a polished apartment marketplace, but one that is personalized by the user's saved searches. The user should immediately understand that this is their own apartment feed, not a generic portal.

## Primary Page Structure

### Left sidebar
The left side of the page should contain the user's saved searches.

Each saved search should behave like a feed selector. Clicking one changes the active result set in the main content area. The sidebar should support the mental model:

**"These are my apartment hunts."**

Sidebar items may later show lightweight supporting metadata such as counts or freshness, but the primary function is navigation between searches.

### Main content area
The main area should be dominated by the listings grid.

The selected search acts as context, not as the main visual object. The user should spend most of their attention scanning apartments, not reading control panels or configuration summaries.

This makes the page feel more like a consumer marketplace and less like a data tool.

## Interaction Model
- User lands on the homepage.
- One saved search is active by default.
- The main grid shows listings for that active search.
- Clicking another saved search swaps the feed shown in the main content area.
- The selected search should feel persistent and obvious, but not visually heavy.

The frontend should communicate that results are continuously updated in the background, even if the exact job/run mechanics are not prominent yet.

## Visual Direction
The chosen tone is closest to **Airbnb-like**:
- warm but clean
- consumer-friendly
- visually polished
- calm and spacious
- easy to browse repeatedly

The UI should feel premium without becoming editorial or ornamental. It should optimize for browsing confidence, not novelty.

## Listing Card Design
The listing card should be **balanced**, not dominated by only one element.

Each card should visibly include:
- image/photo
- price
- neighborhood/location
- key facts such as bedrooms and square meters
- source

The card should be easy to scan vertically and horizontally in a results grid. No single data point should overwhelm the others. The user should be able to compare multiple listings quickly.

## Information Hierarchy
The first polished frontend should prioritize information in this order:

1. Saved searches
2. Listings feed for the selected search
3. Freshness or newness cues
4. Price, neighborhood, and key facts
5. Source
6. Later: match explanations, notification state, and run health

This keeps the product focused on the user's apartment feed while leaving room for richer product intelligence later.

## Product Semantics
The frontend should communicate these product truths:
- searches are durable objects, not temporary filters
- listings belong to saved-search contexts
- the scraper updates results over time
- the user is browsing a personalized feed generated by the system

This is important because it changes how the user interprets the page. The product is not merely "search listings now." It is "review what your searches have found for you."

## Scope for the First Polished Frontend
Included:
- saved-search sidebar
- selected-search result feed
- marketplace-style listings grid
- balanced listing cards
- premium, consumer-facing visual hierarchy

Deferred:
- advanced search management UI
- dense filter builders
- admin or observability-heavy screens
- detailed notification management
- full match-score explanation system on the main surface

## Testing Implications
Frontend work derived from this design should test:
- the selected search controls which results appear
- the page still works cleanly with multiple saved searches
- listing cards render the balanced key information correctly
- the default active-search state is predictable

System or request tests are more valuable here than styling-only tests, because the main requirement is the browsing behavior and content hierarchy.

## Summary
Rental Scout Lite's frontend should evolve into a polished, Airbnb-like apartment marketplace whose key differentiator is that it is powered by saved-search feeds. The user creates searches, the scraper updates them automatically, and the homepage becomes a personalized browsing surface: saved searches on the left, listings grid on the right, with balanced cards and a premium consumer tone.
