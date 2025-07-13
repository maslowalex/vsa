defmodule VSA.SwingDetector do
  @moduledoc """
  Memory-efficient swing point detector that tracks indices explicitly
  and maintains only the minimum required candles (2*lookback+1).
  """

  alias VSA.SwingDetector
  alias VSA.SwingDetector.TrendAnalyzer

  defstruct candles: [],
            lookback: 2,
            swing_highs: [],
            swing_lows: [],
            # Track the absolute position in the dataset
            current_index: 0,
            # Track the last processed index
            processed_index: -1

  @doc """
  Analyzes the trend given SwingDetector data.
  """
  def extract_trend(%SwingDetector{} = detector) do
    TrendAnalyzer.analyze_trends(detector.swing_highs, detector.swing_lows)
  end

  @doc """
  Returns the closest swing point and distance to it.
  """
  def closest_swing(%SwingDetector{swing_highs: [most_recent_high | _]}, :high) do
    {idx, price} = most_recent_high

    distance = detector.current_index - idx

    {:ok, {price, distance}}
  end

  def closest_swing(%SwingDetector{swing_lows: [most_recent_low | _]}, :low) do
    {idx, price} = most_recent_low

    distance = detector.current_index - idx

    {:ok, {price, distance}}
  end

  def closest_swing(_, _), do: {:error, :no_swing_points}

  @doc """
  Creates a new swing detector with the given lookback period.
  """
  def new(lookback \\ 2) do
    %__MODULE__{lookback: lookback}
  end

  @doc """
  Analyzes the given candles to detect swing points.
  """
  def analyze(candles, lookback \\ 2) do
    lookback
    |> new()
    |> add_candles(candles)
  end

  @doc """
  Adds a new candle to the detector and processes it.
  Returns the updated detector with any new swing points found.
  """
  def add_candle(detector, candle) do
    # Add new candle and increment current index
    updated_detector = %{
      detector
      | candles: detector.candles ++ [candle],
        current_index: detector.current_index + 1
    }

    # Process candles if we have enough
    processed_detector = process_candles(updated_detector)

    # Prune candles to keep only what's needed (2*lookback+1)
    prune_candles(processed_detector)
  end

  @doc """
  Adds multiple candles to the detector in sequence.
  """
  def add_candles(%SwingDetector{} = detector, candles) when is_list(candles) do
    Enum.reduce(candles, detector, fn candle, acc -> add_candle(acc, candle) end)
  end

  # Processes the center candle if there are enough candles on both sides.
  defp process_candles(detector) do
    min_candles_needed = 2 * detector.lookback + 1

    if length(detector.candles) >= min_candles_needed do
      # We can now process the center candle (which is at lookback position)
      center_idx = detector.lookback
      center_candle = Enum.at(detector.candles, center_idx)

      # Get the absolute index of this candle
      absolute_idx = detector.current_index - length(detector.candles) + center_idx

      # Only process if this index hasn't been processed yet
      if absolute_idx > detector.processed_index do
        # Get left and right candles for comparison
        left_candles = Enum.slice(detector.candles, 0..(center_idx - 1))
        right_candles = Enum.slice(detector.candles, (center_idx + 1)..(2 * detector.lookback))

        # Check for swing high
        is_swing_high =
          Enum.all?(left_candles ++ right_candles, fn c ->
            c.high < center_candle.high
          end)

        # Check for swing low
        is_swing_low =
          Enum.all?(left_candles ++ right_candles, fn c ->
            c.low > center_candle.low
          end)

        # Update detector with findings
        updated_detector = detector

        updated_detector =
          if is_swing_high do
            %{
              updated_detector
              | swing_highs: [{absolute_idx, center_candle.high} | updated_detector.swing_highs]
            }
          else
            updated_detector
          end

        updated_detector =
          if is_swing_low do
            %{
              updated_detector
              | swing_lows: [{absolute_idx, center_candle.low} | updated_detector.swing_lows]
            }
          else
            updated_detector
          end

        # Mark this index as processed
        %{updated_detector | processed_index: absolute_idx}
      else
        detector
      end
    else
      # Not enough candles yet
      detector
    end
  end

  defp prune_candles(detector) do
    # Prunes candles to maintain only the necessary 2*lookback+1 candles.
    # Always keeps the most recent 2*lookback+1 candles.

    min_candles_needed = 2 * detector.lookback + 1
    current_length = length(detector.candles)

    if current_length > min_candles_needed do
      # Keep only the most recent min_candles_needed candles
      excess = current_length - min_candles_needed
      %{detector | candles: Enum.drop(detector.candles, excess)}
    else
      detector
    end
  end

  @doc """
  Returns the latest swing points, optionally filtered by recency.
  """
  def get_latest_swing_points(detector, count \\ 10) do
    # Sort by index (most recent first) and take specified count
    latest_highs =
      detector.swing_highs
      |> Enum.sort_by(fn {idx, _} -> -idx end)
      |> Enum.take(count)

    latest_lows =
      detector.swing_lows
      |> Enum.sort_by(fn {idx, _} -> -idx end)
      |> Enum.take(count)

    %{highs: latest_highs, lows: latest_lows}
  end

  @doc """
  Returns statistics about the detector's memory usage and processing.
  """
  def stats(detector) do
    %{
      candles_in_memory: length(detector.candles),
      total_candles_seen: detector.current_index,
      processed_up_to: detector.processed_index,
      swing_highs_found: length(detector.swing_highs),
      swing_lows_found: length(detector.swing_lows),
      memory_efficiency:
        "#{(100 * (2 * detector.lookback + 1) / detector.current_index) |> Float.round(2)}%"
    }
  end
end
