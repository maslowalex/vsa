# Changelog

All notable changes to this project are documented here. The format is based on
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0]

Adds the majority of the Tradeguider _Signs of Strength / Signs of Weakness_ principles,
reworks tagging into an event-sourced model, and introduces an optional market-context
boundary. The project is pre-1.0, so the struct/output changes below ship as a minor
release.

### Added

- **New principles.**
  Strength: `:selling_climax`, `:stopping_volume`, `:bag_holding` (two-bar), `:no_supply`,
  `:absorption_volume`.
  Weakness: `:buying_climax`, `:end_of_rising_market`, `:no_result_from_effort`,
  `:churning`, `:no_demand_at_top`, `:wide_spread_down_through_support`.
  See `Vsa.Tag` for each definition. This brings coverage from 8 to 18 principles.
- **Tag provenance.** `VSA.Bar` now carries `:status`
  (`:pending | :assigned | :confirmed | :unconfirmed`) and an append-only `:tag_history` of
  `%VSA.TagEvent{}`. `tag`/`status` are projections of the history head, written
  exclusively through `VSA.Bar.put_tag/4`, so a classification is never overwritten —
  downstream consumers can see when, why, and from what it changed.
- **Injected market context (optional).** Raw bars may include `:trend`
  (`:up | :down | :sideways`) and `:levels` (a list of `%VSA.Level{}` support/resistance).
  These unlock the location-dependent principles. The library never computes trend or
  support/resistance itself.
- **Background regime.** `VSA.Context` exposes `:background`
  (`:strength | :weakness | :neutral`), derived from the active setup, used to distinguish
  No Supply from Test.
- **New thresholds** (all configurable via `VSA.init/1`): `climax_close_min_position`,
  `buying_climax_close_max_position`, `level_proximity_factor`, `effort_volume_step`.
- **New modules:** `VSA.Level`, `VSA.TagEvent`.

### Changed

- **Single tag → single _mutable_ tag.** A bar still has exactly one effective `:tag`, but
  it may be revised by following bars; revisions are appended to `:tag_history` rather than
  discarded.
- **`Vsa.Tag.assign/2`** replaced its first-match-wins clause cascade with an ordered list
  of detectors (most specific first; `professional_*` are the fallback). This surfaces
  patterns the generic professional-buying/selling clauses previously masked.
- **`Vsa.Tag.confirm/2`** no longer clears a tag on a failed confirmation; it records
  `status: :unconfirmed` with the original tag intact (e.g. a failed test is
  `tag: :test, status: :unconfirmed`).
- **Setups now use the new principles.** `VSA.Setup` is no longer limited to the original
  four anchor / four confirmation tags. Setups are **anchored** by `:selling_climax`,
  `:buying_climax`, `:bag_holding` and `:end_of_rising_market` (peers of `:professional_*` /
  the reversals), and **confirmed** by every secondary signal (`:no_supply`,
  `:stopping_volume`, `:absorption_volume`, `:no_demand_at_top`,
  `:wide_spread_down_through_support`, `:no_result_from_effort`, `:churning`). Confirmation
  matching is now dispatched by **polarity** (strength setups accept strength-side
  confirmations, etc.) via the new `VSA.Setup.anchor_polarity/1`, which `VSA.Context`
  reuses for the background regime. This recovers setup coverage that the new detectors
  had shifted away from the generic `:professional_buying` / `:professional_selling` reads.
- The `VSA.Bar` struct gained `:status`, `:tag_history`, `:trend`, `:levels`; JSON output
  changes accordingly.

### Fixed

- `mix generate_data` runs end-to-end again: `Generator.call/2` normalizes OKX `:ts`/`:vol`
  keys to the `:timestamp`/`:volume` the analysis input expects.
- Corrected the `VSA.Bar` documentation, which described the No Demand / Test bar directions
  backwards (No Demand is an up bar; Test is a down bar — the code was already correct).

### Removed

- The `:unconfirmed_test` / `:unconfirmed_no_demand` (and sibling) tag atoms — superseded by
  the orthogonal `:status` field.

## [0.4.0] and earlier

Configurable runtime thresholds, top/bottom reversal tags, and the initial set of eight
principles. See the git history for details.
