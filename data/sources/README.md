# Source evidence versus fixtures

`data/demo/access-notices.json` is a schema fixture, not a live feed. Its only
notice is explicitly simulated, has an empty source URL as permitted for a demo
fixture, and is linked only to the fictional `maize-noodle-lab` location.

`seed_demo_access_notices()` creates fresh relative timestamps when a new isolated
demo store is initialized. It does not overwrite timestamps when `seed_demo()` is
run again against an existing store.

Official-source research belongs in `docs/data/SOURCES.md`; it is intentionally
not used to validate a fictional business or its entrance.
