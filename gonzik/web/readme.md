Static web content root for this Hephaestus profile.

- `sites/` — per-hostname files (`sites/{domain}/`)
- `classes/` — shared class fallbacks (`classes/{class}/`)

DomainHost checks `sites/{hostname}/` first, then `classes/{class}/` (default class: `analytics`).
