defmodule Tymeslot.Availability.SharedOffer do
  @moduledoc """
  The part of `Tymeslot.Availability.Offer` that is about the users a
  `?with=` booking link names (`Tymeslot.Scheduling.SharedAvailability`):
  reading them from the request, reading their schedules once for a range,
  and keeping only the times every one of them can make.

  Split out of `Offer` to keep it inside the size limit. Their calendars are
  read by `Offer` itself, through the same cached fetch as the host's, and
  handed in as a function.
  """

  alias Tymeslot.Scheduling.SharedAvailability

  @doc "The users the request's `?with=` link names, or none."
  @spec guests(map()) :: [SharedAvailability.Guest.t()]
  def guests(request), do: request[:shared_availability_guests] || []

  @doc "The request's named users, with their schedules read once for the whole range."
  @spec prefetched(map(), Date.t(), Date.t()) :: [SharedAvailability.Guest.t()]
  def prefetched(request, start_date, end_date) do
    request
    |> guests()
    |> SharedAvailability.prefetch_schedule_data(start_date, end_date)
  end

  @doc """
  The `slots` on `date` that every one of `guests` is free for, under
  `config`. `events` reads a guest's calendar for a date:
  `(guest, date -> {:ok, events} | {:error, term()})`.
  """
  @spec filter([term()], Date.t(), pos_integer(), map(), list(), map(), function()) ::
          {:ok, [term()]} | {:error, term()}
  def filter(slots, date, duration_minutes, request, guests, config, events) do
    SharedAvailability.filter_slots(
      slots,
      date,
      duration_minutes,
      request.user_timezone,
      guests,
      config,
      events
    )
  end
end
