# Application testing catalog

`places.json` contains 841 named OpenStreetMap places around Ann Arbor, retrieved
September 27, 2026 UTC from the Overpass API. Each record retains its stable OSM
identity, source URL, retrieval timestamp, license, coordinates and quality flags.
See `attribution.txt` and `place-quality.json` for licensing and source limitations.

The app-testing launcher adds 495 fictional food offers to a separate local store.
Their UI uses natural names and copy, as requested for pre-release testing.
Their `is_demo` flags and `dataset-test:` source fields remain set. Public place
records do not establish business participation or validate the generated offers.

Launch and verification instructions: [Dataset testing](../../docs/DATASET-TESTING.md).
