defmodule VSA.Bar do
  @moduledoc """
  A data structure that represents individual price bar analyzed in the VSA terms.
  The lowest-level unit of the system.

  Note, that there is no point in representing / encoding an individual bar
  as in the VSA terms the core principle is the **relative** volume
  meaning that the volume is matters **only** in relation to previous bars

  The properties of bar that we are interesting in is following:
  - An interval that given bar is representing
  - Time period over which bar was captured ** We need this value in order to sort the bars

  - Close price
  - Volume (the absolute amount of volume traded on that particular bar)
  - Spread (absolute spread e.g. high - low)

  - Closed (bottom, middle or top of the actual bar)
  - Direction (up, down or level)
  - Relative Spread (tight, medium, wide)
  - Relative Volume (ultra low, low, average, high, ultra high)

  - Tag that we are assigning to that bar in VSA terms,
    it could be one of following:
      - PS (Potential professional selling). This tag is assigned to an UP bar with ultra-high relative volume and a wide spread
        the next bar is must close **lower** than given bar.
      - PB (Potential professional buying). This tag is assigned to a DOWN bar with ultra-high relative volume and a wide spread
        the next bar is must close **higher** than given bar.
      - Upthrust. This tag is assigned to a DOWN OR LEVEL bar with the ultra-high relative volume, the spread is tight.
      - Shakeout. This tag is assigned to the UP OR LEVEL bar with the ultra-high relative volume, the spread is tight.
      - No demand. This tag is assigned to the DOWN bar, the volume beign ultra-low with the medium to tight spread.
      - Test. This tag is assigned to the UP bar, the volume of which is ultra-low with the medium to tight spread.
  """

  @type t :: %__MODULE__{}

  @enforce_keys [:interval, :time, :close_price, :spread, :volume]
  defstruct [
    :volume,
    :spread,
    :interval,
    :time,
    :close_price,
    :direction,
    :high,
    :low,
    :relative_spread,
    :relative_volume,
    :tag,
    :closed
  ]
end

defimpl String.Chars, for: VSA.Bar do
  def to_string(nil), do: ""

  def to_string(bar) do
    """
    <VSA.Bar
      Timestamp: #{bar.time}
      Volume: #{bar.volume}
      Close Price: #{bar.close_price}
      High: #{bar.high}
      Low: #{bar.low}

      Direction: #{bar.direction}
      Closed: #{bar.closed}
      Relative spread: #{bar.relative_spread}
      Relative volume: #{bar.relative_volume}
    >
    """
  end
end
