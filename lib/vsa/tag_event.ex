defmodule VSA.TagEvent do
  @moduledoc """
  A single entry in a bar's append-only tag history.

  Records one classification decision about a `VSA.Bar`:

    - `tag` — the VSA principle assigned at that moment (the base classification,
      e.g. `:test`, `:professional_buying`).
    - `status` — the state of that classification when the event was recorded:
        - `:assigned` — the bar was just tagged by `Vsa.Tag.assign/2`.
        - `:confirmed` / `:unconfirmed` — the following bar (dis)confirmed it.
        - `:reclassified` — a later bar revised the assumed principle.
    - `at` — the time of the bar that caused this transition.

  The newest event is the head of `VSA.Bar.tag_history`; `VSA.Bar.tag` and
  `VSA.Bar.status` are projections of that head. Because history is append-only,
  a bar always carries the full provenance of how its classification evolved.
  """

  @type status :: :assigned | :confirmed | :unconfirmed | :reclassified
  @type t :: %__MODULE__{}

  @derive JSON.Encoder
  @enforce_keys [:tag, :status, :at]
  defstruct [:tag, :status, :at]
end
