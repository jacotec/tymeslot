defmodule Tymeslot.Availability.SharedOffer do
  @moduledoc """
  The part of `Tymeslot.Availability.Offer` that is about the users a
  `?with=` booking link names (`Tymeslot.Scheduling.SharedAvailability`):
  reading them from the request, reading their schedules once for a range,
  and keeping only the times every one of them can make.

  Split out of `Offer` to keep it inside the size limit. Their calendars are
  read through the same cached fetch as the host's (`Offer.HostCalendar`).
  """

  alias Tymeslot.Availability.Offer.{HostCalendar, Moving}
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

  @doc """
  `filter/7` with each guest's calendar read as the host's is, from their own
  cached booking-window fetch; only the profile the fetch is made for
  differs. When a booking is being rescheduled (`moving`), its invitation in
  a guest's calendar is not a conflict.
  """
  @spec filter_with_calendars([term()], Date.t(), pos_integer(), {map(), term()}, list(), map()) ::
          {:ok, [term()]} | {:error, term()}
  def filter_with_calendars(slots, date, duration_minutes, {request, moving}, guests, config) do
    events = &guest_events(&1, &2, request, moving)
    filter(slots, date, duration_minutes, request, guests, config, events)
  end

  defp guest_events(guest, date, request, moving) do
    with {:ok, events} <- HostCalendar.booking_window(%{request | profile: guest.profile}, date) do
      {:ok, SharedAvailability.exclude_event(events, Moving.uid(moving))}
    end
  end
end
