# VSA for Volume Spread Analysis

Based on the work of Tom Williams (_Master the Markets_) and Gavin Holmes (_Trading in the Shadow of the Smart Money_) and Tradeguider's VSA.

Generate a sample run over real OKX candles by running:
```bash
mix generate_data --instrument=BTC-USDT --bar=1m
```

## Usage

```elixir
context = VSA.init(max_bars: 200, bars_to_mean: 20)
context = VSA.analyze(raw_bars, context)

# context.bars holds the analyzed %VSA.Bar{} structs, newest first.
```

Each raw bar is a map. Required keys: `:high`, `:low`, `:close`, `:volume`, `:timestamp`
(unix ms), `:finished`; optional: `:open`.

### Detected principles (tags)

A bar carries a single **effective** `:tag` — by VSA methodology a bar means one thing at
a time. The currently detected principles:

**Signs of strength:** `:professional_buying`, `:selling_climax`, `:stopping_volume`,
`:bag_holding`, `:shakeout`, `:test`, `:no_supply`, `:bottom_reversal`,
`:absorption_volume`.

**Signs of weakness:** `:professional_selling`, `:buying_climax`, `:end_of_rising_market`,
`:upthrust`, `:no_demand`, `:no_demand_at_top`, `:no_result_from_effort`,
`:wide_spread_down_through_support`, `:top_reversal`, `:churning`.

Detection runs an ordered list of detectors (most specific first); the generic
`professional_*` tags are the fallback.

### Tag provenance (single, but mutable)

A tag is provisional: the following bar may confirm or deny it. Rather than overwriting,
every transition is recorded:

- `bar.tag` — the current effective principle.
- `bar.status` — `:pending | :assigned | :confirmed | :unconfirmed`.
- `bar.tag_history` — an append-only list of `%VSA.TagEvent{tag, status, at}` (newest
  first). `tag`/`status` are projections of its head, so a classification is never lost.

A failed confirmation is `status: :unconfirmed` with the original `tag` intact (e.g. a
failed test is `tag: :test, status: :unconfirmed`).

### Injected market context (optional)

Trend and support/resistance are **not** computed by this library — they are the caller's
concern. Supply them per raw bar to unlock the location-dependent principles:

```elixir
raw_bar = %{
  high: ..., low: ..., close: ..., volume: ..., timestamp: ..., finished: true,
  trend: :up,                                          # :up | :down | :sideways
  levels: [%VSA.Level{price: Decimal.new("100"), kind: :resistance}]
}
```

- `:trend` refines trend-conditional principles (otherwise a local multi-bar proxy is used).
- `:levels` (a list of `%VSA.Level{}`) enables `:absorption_volume`, `:no_demand_at_top`,
  and `:wide_spread_down_through_support`. With no levels, those principles never fire.

### Setups (`VSA.Setup`)

A setup is the trade thesis on `context.setup`: a primary bar **anchors** it and secondary
bars **confirm** it. Every principle plays one role, matched by polarity (a strength setup
only takes strength-side confirmations):

- **Strength anchors:** `:professional_buying`, `:bottom_reversal`, `:selling_climax`,
  `:bag_holding`. **Confirmations:** `:test`, `:no_supply` (must close above the setup high),
  `:shakeout`, `:stopping_volume`, `:absorption_volume`.
- **Weakness anchors:** `:professional_selling`, `:top_reversal`, `:buying_climax`,
  `:end_of_rising_market`. **Confirmations:** `:no_demand`, `:no_demand_at_top` (must close
  below the setup low), `:upthrust`, `:wide_spread_down_through_support`,
  `:no_result_from_effort`, `:churning`.

The latest anchor wins, so an opposite-polarity anchor flips the regime. Each confirmation
is stored with the tag that produced it, so consumers can attribute on the confirming
signal, not just the anchor.

  ## Constants Configuration

  The module uses several configurable constants that define thresholds for VSA analysis:

  ### Extreme Reset Threshold
  - `@bars_to_extreme_reset` (default: 200): Defines the number of bars after which extreme values are reset

  ### Position Thresholds
  - `@position_high_threshold` (default: 0.7): Defines the threshold above which a close/open
    price is considered "high" within the bar's range (70% of the high-low range)
  - `@position_low_threshold` (default: 0.3): Defines the threshold below which a close/open
    price is considered "low" within the bar's range (30% of the high-low range)

  ### Volume Factor Thresholds
  These constants define volume significance relative to the mean volume:
  - `@ultra_high_volume_factor` (default: 2.0): Volume exceeding 2x the average indicates
    exceptional market interest or institutional activity
  - `@high_volume_factor` (default: 1.5): Volume exceeding 1.5x the average suggests
    increased market participation
  - `@low_volume_factor` (default: 0.5): Volume below 0.5x the average indicates
    reduced market interest or lack of institutional participation
  - `@very_low_volume_factor` (default: 0.25): Volume below 0.25x the average suggests
    very thin trading conditions or market disinterest

  ### Spread Factor Constants (Internal)
  - `@wide_spread_factor` (1.5): Used to identify bars with spreads 1.5x larger than average,
    indicating increased volatility or significant price movement
  - `@narrow_spread_factor` (0.7): Used to identify bars with spreads smaller than 70% of average,
    suggesting consolidation or reduced volatility

  ### Pattern Factors
  Used by the extended principles:
  - `climax_close_min_position` (0.3): a selling climax must close at least this far up its range
  - `buying_climax_close_max_position` (0.7): a buying climax / end of rising market must close at
    most this far up its range
  - `level_proximity_factor` (0.5): how close (× mean spread) a bar's high must be to a resistance
    level to count as "at" it
  - `effort_volume_step` (1.0): the volume-increase factor that marks an "effort to rise"

  ## Significance in VSA

  These thresholds are fundamental to Volume Spread Analysis as they help identify:
  - **Professional vs Retail Activity**: Ultra-high volume often indicates smart money
  - **Market Phases**: Low volume suggests accumulation/distribution phases
  - **Support/Resistance**: High closes on wide spreads with high volume suggest strength
  - **Weakness Signs**: Wide spreads with low volume may indicate lack of support

  All constants can be configured via application environment variables for different market conditions.
