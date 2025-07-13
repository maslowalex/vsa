defmodule VSA.Setup do
  @moduledoc """
  The latest occured climactic volume bar (either PS or PB) is the starting point of the setup.

  The setup is considered confirmed when we have a secondary indicator (such as test or no demand) penetrating the high or the low
  of the climactic volume bar, or we observing the SO or UT in the area of the climactic volume bar.
  """

  alias VSA.Bar
  alias VSA.Context

  @derive JSON.Encoder
  defstruct [
    :principle,
    :volume,
    :high,
    :low,
    :close,
    :inception_time,
    confirmations: []
  ]

  @climactic_actions [:professional_buying, :professional_selling]

  def tested?(%VSA.Setup{confirmations: []}), do: false
  def tested?(%VSA.Setup{}), do: true

  def capture(%Context{bars: [%Bar{tag: climactic_action} = climactic_bar | _]})
      when climactic_action in @climactic_actions do
    %VSA.Setup{
      principle: climactic_action,
      volume: climactic_bar.volume,
      high: climactic_bar.high,
      low: climactic_bar.low,
      close: climactic_bar.close_price,
      inception_time: climactic_bar.time
    }
  end

  def capture(%Context{
        bars: [%Bar{tag: :test} = test_bar | _],
        setup: %VSA.Setup{principle: :professional_buying} = setup
      }) do
    if Decimal.gt?(test_bar.close_price, setup.high) do
      bar = take_essential_bar_info(test_bar)

      %VSA.Setup{setup | confirmations: [bar | setup.confirmations]}
    else
      setup
    end
  end

  def capture(%Context{
        bars: [%Bar{tag: :unconfirmed_test} = test_bar | _],
        setup: %VSA.Setup{principle: :professional_selling} = setup
      }) do
    if Decimal.lt?(test_bar.close_price, setup.low) do
      bar = take_essential_bar_info(test_bar)

      %VSA.Setup{setup | confirmations: [bar | setup.confirmations]}
    else
      setup
    end
  end

  def capture(%Context{
        bars: [%Bar{tag: :shakeout} = shakeout_bar | _],
        setup: %VSA.Setup{principle: :professional_buying} = setup
      }) do
    bar = take_essential_bar_info(shakeout_bar)

    %VSA.Setup{setup | confirmations: [bar | setup.confirmations]}
  end

  def capture(%Context{
        bars: [%Bar{tag: :no_demand} = no_demand_bar | _],
        setup: %VSA.Setup{principle: :professional_selling} = setup
      }) do
    if Decimal.lt?(no_demand_bar.close_price, setup.low) do
      bar = take_essential_bar_info(no_demand_bar)

      %VSA.Setup{setup | confirmations: [bar | setup.confirmations]}
    else
      setup
    end
  end

  def capture(%Context{
        bars: [%Bar{tag: :unconfirmed_no_demand} = no_demand_bar | _],
        setup: %VSA.Setup{principle: :professional_buying} = setup
      }) do
    if Decimal.gt?(no_demand_bar.close_price, setup.high) do
      bar = take_essential_bar_info(no_demand_bar)

      %VSA.Setup{setup | confirmations: [bar | setup.confirmations]}
    else
      setup
    end
  end

  def capture(%Context{
        bars: [%Bar{tag: :upthrust} = upthrust_bar | _],
        setup: %VSA.Setup{principle: :professional_selling} = setup
      }) do
    bar = take_essential_bar_info(upthrust_bar)

    %VSA.Setup{setup | confirmations: [bar | setup.confirmations]}
  end

  def capture(%Context{setup: setup}), do: setup

  defp take_essential_bar_info(bar) do
    Map.take(bar, [:tag, :close_price, :high, :low, :volume, :time, :relative_volume, :relative_spread])
  end
end
