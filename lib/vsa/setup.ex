defmodule VSA.Setup do
  @moduledoc """
  The latest occured climactic volume bar (either PS or PB) is the starting point of the setup.

  The setup is considered confirmed when we have a secondary indicator (such as test or no demand) penetrating the high or the low
  of the climactic volume bar, or we observing the SO or UT in the area of the climactic volume bar.
  """

  alias VSA.Bar
  alias VSA.Context

  defstruct [
    :principle,
    :volume,
    :high,
    :low,
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
      low: climactic_bar.low
    }
  end

  def capture(%Context{
        bars: [%Bar{tag: :test} = test_bar | _],
        setup: %VSA.Setup{principle: :professional_buying} = setup
      }) do
    if Decimal.compare(test_bar.close_price, setup.high) in [:gt, :eq] do
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
    if Decimal.compare(no_demand_bar.close_price, setup.low) in [:gt, :eq] do
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
    Map.take(bar, [:tag, :close_price, :relative_volume, :relative_spread])
  end
end
