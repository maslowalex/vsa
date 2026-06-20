defmodule VSA.Bar do
  @moduledoc """
  A single price bar analyzed in VSA terms — the lowest-level unit of the system.

  In VSA only **relative** quantities matter: a bar's volume and spread are meaningful only
  against the recent average, so a bar stores both the raw values and their classified
  forms.

  ## Fields

  Raw market data:

    * `:time` — the bar's timestamp (used to order bars)
    * `:high`, `:low`, `:close_price`, `:volume`
    * `:spread` — absolute spread (`high - low`)
    * `:finished` — whether the bar is closed

  Derived classifications (relative to the rolling means, or to the bar's own range):

    * `:direction` — `:up | :down | :level` (close vs the previous close)
    * `:relative_spread` — `:narrow | :average | :wide`
    * `:relative_volume` — `:very_low | :low | :average | :high | :ultra_high`
    * `:closed`, `:opened` — where close/open sit within the bar:
      `:very_low | :low | :middle | :high | :very_high`

  VSA classification and its provenance:

    * `:tag` — the current effective principle, or `nil`. See `Vsa.Tag` for the catalogue.
    * `:status` — `:pending | :assigned | :confirmed | :unconfirmed`
    * `:tag_history` — append-only list of `VSA.TagEvent` (newest first). `:tag` and
      `:status` are projections of its head, so the full classification history is retained.
      Always write through `put_tag/4`; never set `:tag` directly.

  Optional, caller-supplied market context (see `VSA.Level`):

    * `:trend` — `:up | :down | :sideways` (refines trend-conditional principles)
    * `:levels` — support/resistance levels that enable the location-dependent principles
  """

  @type t :: %__MODULE__{}

  @derive JSON.Encoder
  @enforce_keys [:time, :close_price, :spread, :volume]
  defstruct [
    :volume,
    :spread,
    :time,
    :close_price,
    :direction,
    :high,
    :low,
    :relative_spread,
    :relative_volume,
    :tag,
    :closed,
    :opened,
    :finished,
    status: :pending,
    tag_history: [],
    trend: nil,
    levels: []
  ]

  @doc """
  Sets the bar's current effective `tag` and `status`, appending the transition to
  `tag_history` (newest-first).

  This is the single writer of a bar's tag state: `tag`/`status` are always the
  projection of the most recent `VSA.TagEvent`, so a classification is never
  overwritten in place and the full provenance is preserved. `at` is the time of
  the bar that caused the transition.
  """
  @spec put_tag(t(), atom(), VSA.TagEvent.status(), term()) :: t()
  def put_tag(%__MODULE__{} = bar, tag, status, at) do
    event = %VSA.TagEvent{tag: tag, status: status, at: at}
    %{bar | tag: tag, status: status, tag_history: [event | bar.tag_history]}
  end
end

defimpl String.Chars, for: VSA.Bar do
  def to_string(%{tag: nil} = bar) do
    """
    <VSA.Bar
      Timestamp: #{bar.time}
      Volume: #{bar.volume}
      High: #{bar.high}
      Low: #{bar.low}
      Close Price: #{bar.close_price}

      Direction: #{bar.direction}
      Closed: #{bar.closed}
      Opened: #{bar.opened}
      Relative spread: #{bar.relative_spread}
      Relative volume: #{bar.relative_volume}
    >
    """
  end

  def to_string(%{tag: tag} = bar) do
    """
    <VSA.Bar
      Timestamp: #{bar.time}
      Volume: #{bar.volume}
      High: #{bar.high}
      Low: #{bar.low}
      Close Price: #{bar.close_price}

      Direction: #{bar.direction}
      Closed: #{bar.closed}
      Relative spread: #{bar.relative_spread}
      Relative volume: #{bar.relative_volume}

      Tag: #{tag}
      Status: #{bar.status}
    >
    """
  end
end
