defmodule Tymeslot.Availability.OfferSharedAvailabilityOfferedTimesTest do
  @moduledoc """
  A combined booking link (`?with=`) to a one-to-one meeting type with fixed
  dates: the host's offered times replace their weekly hours as the
  candidates, and each named user still has to be free for one.

  The offered times reach the host's config through `Schedules.config/2` as
  `:offered_starts`. A named user's config is built from their own schedule
  (`SharedAvailability.guest_config/2`) and must not take them over, or every
  offered time would look free for them too.
  """

  use Tymeslot.DataCase, async: false

  @moduletag :availability
  @moduletag :bookings

  import Tymeslot.AvailabilityTestHelpers
  import Tymeslot.Factory

  alias Tymeslot.Availability.Offer
  alias Tymeslot.Bookings.Create
  alias Tymeslot.Infrastructure.AvailabilityCache
  alias Tymeslot.MeetingTypes.OfferedTimes
  alias Tymeslot.Scheduling.SharedAvailability

  @timezone "Etc/UTC"
  @afternoon %{is_available: true, start_time: ~T[13:00:00], end_time: ~T[17:00:00]}

  setup do
    Mox.stub(Tymeslot.CalendarMock, :get_booking_integration_info, fn _context ->
      {:error, :no_integration}
    end)

    Mox.stub(Tymeslot.CalendarMock, :get_events_for_range_fresh, fn _user_id, _from, _to ->
      {:ok, []}
    end)

    AvailabilityCache.clear_all()

    # Open on no weekday: only the offered times can put anything on offer.
    %{user: host, profile: profile} =
      create_bookable_profile(profile: %{username: "marco"}, timezone: @timezone, days: [])

    meeting_type =
      insert(:meeting_type,
        user: host,
        duration_minutes: 30,
        max_participants: 1,
        fixed_dates: true,
        allow_guests: true,
        is_active: true
      )

    day = Date.add(Date.utc_today(), 10)

    for time <- [~T[09:00:00], ~T[14:00:00], ~T[20:30:00]] do
      {:ok, _offered} = OfferedTimes.add(meeting_type, host.id, DateTime.new!(day, time))
    end

    %{user: michael} =
      create_bookable_profile(
        profile: %{username: "michael"},
        timezone: @timezone,
        days: Enum.to_list(1..7),
        hours: @afternoon
      )

    insert(:calendar_integration, user: michael)
    insert(:meeting_type, user: michael)

    {:ok, guests} = SharedAvailability.resolve(["michael"], host.id)

    %{
      host: host,
      profile: profile,
      meeting_type: meeting_type,
      day: day,
      guests: guests
    }
  end

  defp offered(ctx, guests) do
    AvailabilityCache.clear_all()

    request = %{
      profile: ctx.profile,
      user_timezone: @timezone,
      meeting_type: ctx.meeting_type,
      shared_availability_guests: guests
    }

    {:ok, slots} = Offer.slots_for_date(request, Date.to_iso8601(ctx.day), 30)
    slots
  end

  defp book(ctx, time) do
    Create.execute(
      %{
        date: ctx.day,
        time: time,
        duration: "30min",
        user_timezone: @timezone,
        organizer_user_id: ctx.host.id,
        meeting_type_id: ctx.meeting_type.id,
        shared_availability_usernames: ["michael"]
      },
      %{"name" => "Booker", "email" => "booker@example.com"}
    )
  end

  test "offers only the offered times the named user is free for", ctx do
    # Anchor: on their own the host offers all three times.
    assert length(offered(ctx, [])) == 3

    assert [only] = offered(ctx, ctx.guests)
    assert only =~ "2:00"
  end

  test "books an offered time the named user is free for", ctx do
    assert {:ok, _meeting} = book(ctx, "14:00")
  end

  test "refuses an offered time outside the named user's working hours", ctx do
    assert {:error, :slot_taken} = book(ctx, "09:00")
  end
end
