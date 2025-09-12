# VSA for Volume Spread Analysis

Based on the work of Tom Williams (_Master the Markets_) and Gavin Holmes (_Trading in the Shadow of the Smart Money_) and Tradeguider's VSA.

Test the implementation by running:
```bash
mix generate_data --instrument=BTC-USDT --bar=1m
```

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

  ## Significance in VSA

  These thresholds are fundamental to Volume Spread Analysis as they help identify:
  - **Professional vs Retail Activity**: Ultra-high volume often indicates smart money
  - **Market Phases**: Low volume suggests accumulation/distribution phases
  - **Support/Resistance**: High closes on wide spreads with high volume suggest strength
  - **Weakness Signs**: Wide spreads with low volume may indicate lack of support

  All constants can be configured via application environment variables for different market conditions.
