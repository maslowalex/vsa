defmodule VSA.Fixtures do
  alias VSA.Bar
  alias VSA.Context

  def context(opts \\ []) do
    bars = Keyword.get(opts, :bars, [])
    setup = Keyword.get(opts, :setup)
    price_high = Keyword.get(opts, :price_high)
    price_low = Keyword.get(opts, :price_high)
    volume_extreme = Keyword.get(opts, :volume_extreme)

    %Context{
      bars: bars,
      setup: setup,
      price_high: price_high,
      price_low: price_low,
      volume_extreme: volume_extreme
    }
  end

  def context_with_climactic_last_bar(options \\ []) do
    tag = Keyword.get(options, :tag, :professional_buying)

    volume = Keyword.get(options, :volume, Decimal.new("10000"))
    high = Keyword.get(options, :high, Decimal.new("65000"))
    low = Keyword.get(options, :low, Decimal.new("64000"))
    close_price = Keyword.get(options, :close_price, Decimal.new("64500"))

    mean_volume = Keyword.get(options, :mean_volume, Decimal.new("5000"))
    price_high = Keyword.get(options, :price_high, Decimal.new("66000"))
    price_low = Keyword.get(options, :price_low, Decimal.new("62000"))

    bar_fields = %{
      tag: tag,
      volume: volume,
      high: high,
      low: low,
      close_price: close_price,
      time: ~N[2025-10-01 12:00:00]
    }

    context(bars: [bar(bar_fields)], mean_vol: mean_volume, price_high: price_high, price_low: price_low)
  end

  def context_with_setup(options) do
    setup = Keyword.fetch!(options, :setup)

    context(options)
    |> Map.put(:setup, setup)
  end

  def bar(bar_fields) when is_map(bar_fields) do
    bar_fields
    |> Map.put_new(:time, NaiveDateTime.utc_now())
    |> Map.put_new(:spread, random_decimal())
    |> Map.put_new(:high, Decimal.new("65000"))
    |> Map.put_new(:low, Decimal.new("64000"))
    |> Map.put_new(:close_price, Decimal.new("64500"))
    |> Map.put_new(:direction, Enum.random([:up, :down, :level]))
    |> Map.put_new(:trend, Enum.random([:up, :down, :flat]))
    |> Map.put_new(:relative_spread, Enum.random([:wide, :narrow, :average]))
    |> Map.put_new(:relative_volume, Enum.random([:ultra_high, :high, :average, :low, :ultra_low]))
    |> Map.put_new(:finished, true)
    |> then(fn fields -> struct!(Bar, fields) end)
  end

  def random_bar do
    tag = Enum.random([:professional_buying, :professional_selling, :shakeout, :no_demand, :test, :unconfirmed_test, :unconfirmed_no_demand, :upthrust, nil])

    bar(%{tag: tag, volume: volume_from_tag(tag)})
  end

  def volume_from_tag(tag) when tag in [:professional_buying, :professional_selling] do
    :rand.uniform()
    |> :math.pow(5)
    |> to_decimal()
  end

  def volume_from_tag(tag) when tag in [:shakeout, :upthrust] do
    :rand.uniform()
    |> :math.pow(3)
    |> to_decimal()
  end

  def volume_from_tag(_) do
    :rand.uniform()
    |> :math.pow(2)
    |> to_decimal()
  end

  def random_decimal do
    :rand.uniform()
    |> random_exponent()
    |> to_decimal()
  end

  def random_exponent(float) do
    exponent = :rand.uniform(10)

    :math.pow(float, exponent)
  end

  def to_decimal(float), do: Decimal.from_float(float)
end
