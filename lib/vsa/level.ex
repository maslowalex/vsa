defmodule VSA.Level do
  @moduledoc """
  A support or resistance price level supplied by the caller.

  Trend and support/resistance are deliberately **not** computed by this library —
  they are the caller's concern. They are accepted, optionally, through the
  analysis input so that location-dependent VSA principles (absorption volume, no
  demand at a market top, wide-spread down through support) can be detected. A bar
  with no `:levels` simply will not trigger those principles.

  Levels are attached per raw bar (see `VSA.Bar` `:levels`) so they can evolve as
  the market does.
  """

  @type kind :: :support | :resistance
  @type t :: %__MODULE__{price: Decimal.t(), kind: kind()}

  @derive JSON.Encoder
  @enforce_keys [:price, :kind]
  defstruct [:price, :kind]
end
