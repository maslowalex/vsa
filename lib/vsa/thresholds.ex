defmodule VSA.Thresholds do
  @moduledoc """
  Configuration thresholds for VSA analysis.

  All thresholds have sensible defaults matching historical behavior.
  Values can be overridden at initialization time via `VSA.init/1`.

  ## Validation Constraints

  Position thresholds (must be within 0-1 range):
    0 < position_low_threshold < position_high_threshold < 1

  Volume factors (must maintain hierarchy):
    0 < very_low_volume_factor < low_volume_factor < 1 < high_volume_factor < ultra_high_volume_factor

  Spread factors:
    0 < narrow_spread_factor < 1 < wide_spread_factor

  Other:
    bars_to_extreme_reset > 0
  """

  alias Decimal, as: D

  @one D.new(1)
  @zero D.new(0)

  # Default values from application config or hardcoded defaults
  @default_position_high_threshold Application.compile_env(:vsa, :position_high_threshold, D.new("0.7"))
  @default_position_low_threshold Application.compile_env(:vsa, :position_low_threshold, D.new("0.3"))
  @default_ultra_high_volume_factor Application.compile_env(:vsa, :ultra_high_volume_factor, D.new("2.0"))
  @default_high_volume_factor Application.compile_env(:vsa, :high_volume_factor, D.new("1.5"))
  @default_low_volume_factor Application.compile_env(:vsa, :low_volume_factor, D.new("0.5"))
  @default_very_low_volume_factor Application.compile_env(:vsa, :very_low_volume_factor, D.new("0.25"))
  @default_wide_spread_factor Application.compile_env(:vsa, :wide_spread_factor, D.new("1.5"))
  @default_narrow_spread_factor Application.compile_env(:vsa, :narrow_spread_factor, D.new("0.7"))
  @default_bars_to_extreme_reset Application.compile_env(:vsa, :bars_to_extreme_reset, 200)

  @derive JSON.Encoder
  defstruct position_high_threshold: D.new("0.7"),
            position_low_threshold: D.new("0.3"),
            ultra_high_volume_factor: D.new("2.0"),
            high_volume_factor: D.new("1.5"),
            low_volume_factor: D.new("0.5"),
            very_low_volume_factor: D.new("0.25"),
            wide_spread_factor: D.new("1.5"),
            narrow_spread_factor: D.new("0.7"),
            bars_to_extreme_reset: 200

  @type t :: %__MODULE__{
          position_high_threshold: Decimal.t(),
          position_low_threshold: Decimal.t(),
          ultra_high_volume_factor: Decimal.t(),
          high_volume_factor: Decimal.t(),
          low_volume_factor: Decimal.t(),
          very_low_volume_factor: Decimal.t(),
          wide_spread_factor: Decimal.t(),
          narrow_spread_factor: Decimal.t(),
          bars_to_extreme_reset: pos_integer()
        }

  @doc """
  Creates a new Thresholds struct from keyword options.
  Returns `{:ok, thresholds}` on success, `{:error, reasons}` on validation failure.

  ## Examples

      iex> VSA.Thresholds.new()
      {:ok, %VSA.Thresholds{}}

      iex> VSA.Thresholds.new(position_high_threshold: Decimal.new("0.8"))
      {:ok, %VSA.Thresholds{position_high_threshold: Decimal.new("0.8"), ...}}

      iex> VSA.Thresholds.new(position_high_threshold: Decimal.new("0.2"))
      {:error, ["position_high_threshold (0.2) must be greater than position_low_threshold (0.3)"]}
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, list(String.t())}
  def new(opts \\ []) do
    thresholds = build_from_opts(opts)

    case validate(thresholds) do
      :ok -> {:ok, thresholds}
      {:error, _} = error -> error
    end
  end

  @doc """
  Creates a new Thresholds struct from keyword options.
  Raises `ArgumentError` on validation failure.

  ## Examples

      iex> VSA.Thresholds.new!()
      %VSA.Thresholds{}

      iex> VSA.Thresholds.new!(position_high_threshold: Decimal.new("0.2"))
      ** (ArgumentError) Invalid thresholds: ...
  """
  @spec new!(keyword()) :: t()
  def new!(opts \\ []) do
    case new(opts) do
      {:ok, thresholds} -> thresholds
      {:error, reasons} -> raise ArgumentError, "Invalid thresholds: #{Enum.join(reasons, "; ")}"
    end
  end

  @doc """
  Validates a Thresholds struct against all constraints.
  Returns `:ok` if valid, `{:error, reasons}` with list of violation messages otherwise.
  """
  @spec validate(t()) :: :ok | {:error, list(String.t())}
  def validate(%__MODULE__{} = t) do
    errors =
      []
      |> validate_position_thresholds(t)
      |> validate_volume_factors(t)
      |> validate_spread_factors(t)
      |> validate_bars_to_extreme_reset(t)

    case errors do
      [] -> :ok
      _ -> {:error, Enum.reverse(errors)}
    end
  end

  defp build_from_opts(opts) do
    base = %__MODULE__{
      position_high_threshold: @default_position_high_threshold,
      position_low_threshold: @default_position_low_threshold,
      ultra_high_volume_factor: @default_ultra_high_volume_factor,
      high_volume_factor: @default_high_volume_factor,
      low_volume_factor: @default_low_volume_factor,
      very_low_volume_factor: @default_very_low_volume_factor,
      wide_spread_factor: @default_wide_spread_factor,
      narrow_spread_factor: @default_narrow_spread_factor,
      bars_to_extreme_reset: @default_bars_to_extreme_reset
    }

    opts
    |> Enum.reduce(base, fn {key, value}, acc ->
      if Map.has_key?(acc, key) do
        Map.put(acc, key, to_decimal_if_needed(key, value))
      else
        acc
      end
    end)
  end

  defp to_decimal_if_needed(:bars_to_extreme_reset, value), do: value

  defp to_decimal_if_needed(_key, %Decimal{} = value), do: value
  defp to_decimal_if_needed(_key, value) when is_binary(value), do: D.new(value)
  defp to_decimal_if_needed(_key, value) when is_float(value), do: D.from_float(value)
  defp to_decimal_if_needed(_key, value) when is_integer(value), do: D.new(value)

  # Position thresholds: 0 < low < high < 1
  defp validate_position_thresholds(errors, %{
         position_low_threshold: low,
         position_high_threshold: high
       }) do
    errors
    |> add_error_if(
      not D.gt?(low, @zero),
      "position_low_threshold (#{low}) must be greater than 0"
    )
    |> add_error_if(
      not D.lt?(low, @one),
      "position_low_threshold (#{low}) must be less than 1"
    )
    |> add_error_if(
      not D.gt?(high, @zero),
      "position_high_threshold (#{high}) must be greater than 0"
    )
    |> add_error_if(
      not D.lt?(high, @one),
      "position_high_threshold (#{high}) must be less than 1"
    )
    |> add_error_if(
      not D.gt?(high, low),
      "position_high_threshold (#{high}) must be greater than position_low_threshold (#{low})"
    )
  end

  # Volume factors: 0 < very_low < low < 1 < high < ultra_high
  defp validate_volume_factors(errors, %{
         very_low_volume_factor: very_low,
         low_volume_factor: low,
         high_volume_factor: high,
         ultra_high_volume_factor: ultra_high
       }) do
    errors
    |> add_error_if(
      not D.gt?(very_low, @zero),
      "very_low_volume_factor (#{very_low}) must be greater than 0"
    )
    |> add_error_if(
      not D.gt?(low, very_low),
      "low_volume_factor (#{low}) must be greater than very_low_volume_factor (#{very_low})"
    )
    |> add_error_if(
      not D.lt?(low, @one),
      "low_volume_factor (#{low}) must be less than 1"
    )
    |> add_error_if(
      not D.gt?(high, @one),
      "high_volume_factor (#{high}) must be greater than 1"
    )
    |> add_error_if(
      not D.gt?(ultra_high, high),
      "ultra_high_volume_factor (#{ultra_high}) must be greater than high_volume_factor (#{high})"
    )
  end

  # Spread factors: 0 < narrow < 1 < wide
  defp validate_spread_factors(errors, %{
         narrow_spread_factor: narrow,
         wide_spread_factor: wide
       }) do
    errors
    |> add_error_if(
      not D.gt?(narrow, @zero),
      "narrow_spread_factor (#{narrow}) must be greater than 0"
    )
    |> add_error_if(
      not D.lt?(narrow, @one),
      "narrow_spread_factor (#{narrow}) must be less than 1"
    )
    |> add_error_if(
      not D.gt?(wide, @one),
      "wide_spread_factor (#{wide}) must be greater than 1"
    )
  end

  # bars_to_extreme_reset > 0
  defp validate_bars_to_extreme_reset(errors, %{bars_to_extreme_reset: bars}) do
    add_error_if(
      errors,
      not (is_integer(bars) and bars > 0),
      "bars_to_extreme_reset (#{bars}) must be a positive integer"
    )
  end

  defp add_error_if(errors, true, message), do: [message | errors]
  defp add_error_if(errors, false, _message), do: errors
end
