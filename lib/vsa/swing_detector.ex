defmodule VSA.SwingDetector do
  @moduledoc """
  A module for detecting swing highs and lows in candlestick data.
  Uses Nx for efficient numerical operations.
  """

  defstruct lookback: 2,
            candles: [],
            # List of {index, price} tuples
            swing_highs: [],
            # List of {index, price} tuples
            swing_lows: []

  alias VSA.SwingDetector
  alias VSA.SwingDetector.TrendAnalyzer

  @doc """
  Analyzes the trend given SwingDetector data.
  """
  def extract_trend(%SwingDetector{} = detector) do
    TrendAnalyzer.analyze_trends(detector.swing_highs, detector.swing_lows)
  end

  @doc """
  Creates a new SwingDetector with the specified lookback period.
  """
  def new(lookback \\ 2) do
    %SwingDetector{lookback: lookback}
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
  Adds a new candle to the detector and updates swing points.

  Expected candle format: %{time: timestamp, open: float, high: float,
                           low: float, close: float}
  """
  def add_candle(%SwingDetector{} = detector, candle) do
    updated_detector = %{detector | candles: detector.candles ++ [candle]}

    # We need at least 2*lookback + 1 candles to identify a swing point
    if length(updated_detector.candles) >= 2 * updated_detector.lookback + 1 do
      check_swing_points(updated_detector)
    else
      updated_detector
    end
  end

  @doc """
  Adds multiple candles to the detector in sequence.
  """
  def add_candles(%SwingDetector{} = detector, candles) when is_list(candles) do
    Enum.reduce(candles, detector, fn candle, acc -> add_candle(acc, candle) end)
  end

  @doc """
  Checks if a new swing point has formed with the latest data.
  """
  def check_swing_points(%SwingDetector{} = detector) do
    # We'll check if the candle at position (-lookback-1) is a swing point
    check_index = length(detector.candles) - detector.lookback - 1

    # Extract the relevant candles for comparison
    center_candle = Enum.at(detector.candles, check_index)

    left_range = (check_index - detector.lookback)..(check_index - 1)
    left_candles = Enum.slice(detector.candles, left_range)

    right_range = (check_index + 1)..(check_index + detector.lookback)
    right_candles = Enum.slice(detector.candles, right_range)

    comparison_candles = left_candles ++ right_candles

    # Check for swing high
    is_swing_high =
      Enum.all?(comparison_candles, fn candle ->
        candle.high < center_candle.high
      end)

    # Check for swing low
    is_swing_low =
      Enum.all?(comparison_candles, fn candle ->
        candle.low > center_candle.low
      end)

    # Update the swing points
    detector =
      if is_swing_high do
        %{
          detector
          | swing_highs: [
              {check_index, center_candle.high} | detector.swing_highs
            ]
        }
      else
        detector
      end

    if is_swing_low do
      %{
        detector
        | swing_lows: [{check_index, center_candle.low} | detector.swing_lows]
      }
    else
      detector
    end
  end

  @doc """
  Returns all detected swing points.
  """
  def get_swing_points(%SwingDetector{} = detector) do
    %{
      highs: detector.swing_highs,
      lows: detector.swing_lows
    }
  end

  @doc """
  Returns the most recent n swing points of each type.
  """
  def get_latest_swing_points(%SwingDetector{} = detector, n \\ 5) do
    %{
      highs: Enum.take(Enum.reverse(detector.swing_highs), n),
      lows: Enum.take(Enum.reverse(detector.swing_lows), n)
    }
  end

  ### Experimental Nx Implementation ###

  @doc """
  Experimental: Nx implementation for analyzing swing points.
  """
  def analyze_nx(bars, lookback \\ 2) do
    lookback
    |> new()
    |> put_candles(bars)
    |> analyze_with_nx()
  end

  @doc """
  Puts the candles into the detector.
  """
  def put_candles(%SwingDetector{} = detector, candles) do
    %SwingDetector{detector | candles: candles}
  end

  @doc """
  Implementation using Nx for more efficient processing with large datasets.
  This function creates tensors for candle highs and lows to perform vectorized operations.
  """
  def analyze_with_nx(%SwingDetector{} = detector) do
    if length(detector.candles) < 2 * detector.lookback + 1 do
      detector
    else
      # Extract highs and lows into lists
      highs = Enum.map(detector.candles, &Decimal.to_float(&1.high))
      lows = Enum.map(detector.candles, &Decimal.to_float(&1.low))

      # Convert to Nx tensors
      highs_tensor = Nx.tensor(highs)
      lows_tensor = Nx.tensor(lows)

      # Identify swing points
      swing_highs = identify_swing_highs(highs_tensor, detector.lookback)
      swing_lows = identify_swing_lows(lows_tensor, detector.lookback)

      # Update the detector with the results
      %{
        detector
        | swing_highs: format_swing_points(swing_highs, highs),
          swing_lows: format_swing_points(swing_lows, lows)
      }
    end
  end

  defp identify_swing_highs(highs_tensor, lookback) do
    # We'll use a sliding window approach
    # A swing high occurs when the center value is greater than all values within lookback on both sides
    n = Nx.size(highs_tensor)

    if n < 2 * lookback + 1 do
      []
    else
      indices = for i <- lookback..(n - lookback - 1), do: i

      Enum.filter(indices, fn i ->
        center = Nx.slice(highs_tensor, [i], [1]) |> Nx.to_flat_list() |> List.first()

        # Check left side
        left_start = i - lookback
        left = Nx.slice(highs_tensor, [left_start], [lookback])
        left_max = Nx.to_number(Nx.reduce_max(left))

        # Check right side
        right_start = i + 1
        right = Nx.slice(highs_tensor, [right_start], [lookback])
        right_max = Nx.to_number(Nx.reduce_max(right))

        # It's a swing high if center is greater than both left and right max
        center > left_max && center > right_max
      end)
    end
  end

  defp identify_swing_lows(lows_tensor, lookback) do
    # Similar approach for swing lows
    n = Nx.size(lows_tensor)

    if n < 2 * lookback + 1 do
      []
    else
      indices = for i <- lookback..(n - lookback - 1), do: i

      Enum.filter(indices, fn i ->
        center = Nx.slice(lows_tensor, [i], [1]) |> Nx.to_flat_list() |> List.first()

        # Check left side
        left_start = i - lookback
        left = Nx.slice(lows_tensor, [left_start], [lookback])
        left_min = Nx.to_number(Nx.reduce_min(left))

        # Check right side
        right_start = i + 1
        right = Nx.slice(lows_tensor, [right_start], [lookback])
        right_min = Nx.to_number(Nx.reduce_min(right))

        # It's a swing low if center is less than both left and right min
        center < left_min && center < right_min
      end)
    end
  end

  defp format_swing_points(indices, values) do
    indices
    |> Enum.map(fn i -> {i, Enum.at(values, i)} end)
    |> Enum.reverse()
  end
end
