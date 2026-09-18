defmodule Tymeslot.MeetingTypes.Durations do
  @moduledoc """
  The lengths a meeting type offers the booker.

  A meeting type always has its own `duration_minutes`. It may also offer
  further lengths (`extra_durations_minutes`), and the booker then picks one
  in a step of its own before choosing a time. Everything that asks "how long
  may a booking of this type be" goes through here, so the primary duration
  and the extras are never read as two different rules.
  """

  alias Tymeslot.MeetingTypes.MeetingTypeSchema, as: MeetingType

  @doc """
  Every duration the type offers, in minutes, ascending and without repeats.
  """
  @spec offered(MeetingType.t() | map()) :: [pos_integer()]
  def offered(%{duration_minutes: primary} = meeting_type) when is_integer(primary) do
    [primary | extras(meeting_type)]
    |> Enum.uniq()
    |> Enum.sort()
  end

  def offered(_meeting_type), do: []

  @doc "Whether the booker has more than one duration to choose from."
  @spec multiple?(MeetingType.t() | map() | nil) :: boolean()
  def multiple?(nil), do: false
  def multiple?(meeting_type), do: length(offered(meeting_type)) > 1

  @doc "Whether `minutes` is one of the durations the type offers."
  @spec offers?(MeetingType.t() | map() | nil, term()) :: boolean()
  def offers?(nil, _minutes), do: false

  def offers?(meeting_type, minutes) when is_integer(minutes),
    do: minutes in offered(meeting_type)

  def offers?(_meeting_type, _minutes), do: false

  @doc """
  The duration a booking of this type lasts: `minutes` when the type offers
  it, otherwise the type's own `duration_minutes`.
  """
  @spec resolve(MeetingType.t() | map(), term()) :: pos_integer() | nil
  def resolve(meeting_type, minutes) do
    if offers?(meeting_type, minutes), do: minutes, else: Map.get(meeting_type, :duration_minutes)
  end

  @doc """
  Parses a duration the booker chose, as it arrives in a URL or an event:
  `"45"`, `"45min"` or an integer. Anything else is `nil`.
  """
  @spec parse(term()) :: pos_integer() | nil
  def parse(minutes) when is_integer(minutes) and minutes > 0, do: minutes

  def parse(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {minutes, rest} when minutes > 0 and rest in ["", "min"] -> minutes
      _other -> nil
    end
  end

  def parse(_value), do: nil

  defp extras(meeting_type) do
    case Map.get(meeting_type, :extra_durations_minutes) do
      list when is_list(list) -> Enum.filter(list, &is_integer/1)
      _none -> []
    end
  end
end
