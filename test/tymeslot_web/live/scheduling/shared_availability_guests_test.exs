defmodule TymeslotWeb.Live.Scheduling.SharedAvailabilityGuestsTest do
  @moduledoc """
  The booking page side of `?with=`: the overview names the other users, only
  meeting types that allow guests are offered, and a link naming someone who
  cannot take part shows an error instead of the flow, in every theme.
  """

  use TymeslotWeb.ConnCase, async: false

  @moduletag :scheduling

  import Mox
  import Phoenix.LiveViewTest
  import Tymeslot.Factory

  alias Ecto.Changeset
  alias Tymeslot.Meetings.Guests
  alias Tymeslot.Profiles
  alias Tymeslot.Repo

  setup do
    stub(Tymeslot.CalendarMock, :get_events_for_range_fresh, fn _user, _start, _stop ->
      {:ok, []}
    end)

    host = insert(:user)
    insert(:profile, user: host, username: "marco", booking_theme: "1")
    insert(:calendar_integration, user: host)
    insert(:meeting_type, user: host, name: "Team call", allow_guests: true)
    insert(:meeting_type, user: host, name: "Solo call", allow_guests: false)

    insert(:meeting_type,
      user: host,
      name: "Group workshop",
      allow_guests: true,
      max_participants: 5
    )

    michael = insert(:user, name: "Michael Example")
    insert(:profile, user: michael, username: "michael", full_name: "Michael Example")
    insert(:calendar_integration, user: michael)
    insert(:meeting_type, user: michael)

    %{host: host, michael: michael}
  end

  test "names the other participants and offers only meeting types with guests", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/marco?with=michael")

    assert html =~ "Additional participants: Michael Example"
    assert html =~ "Team call"
    refute html =~ "Solo call"
    refute html =~ "Group workshop"
  end

  test "shows an error for a participant who cannot be booked", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/marco?with=michael,nobody")

    # Shown on the booking page itself, not the generic error screen.
    assert html =~ "This booking link can’t be used"
    assert html =~ "One of the participants named in this link"
    refute html =~ "Theme Error"
    refute html =~ "Team call"
  end

  test "a reschedule names the guests who are Tymeslot users", %{
    conn: conn,
    host: host,
    michael: michael
  } do
    meeting =
      insert(:meeting,
        organizer_user_id: host.id,
        start_time: DateTime.add(DateTime.utc_now(), 3, :day),
        end_time: DateTime.add(DateTime.utc_now(), 3 * 86_400 + 1_800, :second)
      )

    {:ok, _guests} = Guests.create_for_meeting(meeting.id, [michael.email])

    {:ok, _view, html} = live(conn, "/marco?reschedule_meeting_uid=#{meeting.uid}")

    assert html =~ "Additional participants: Michael Example"
  end

  test "leaves the plain booking link unchanged", %{conn: conn} do
    {:ok, _view, html} = live(conn, "/marco")

    refute html =~ "Additional participants"
    assert html =~ "Team call"
    assert html =~ "Solo call"
  end

  # Paper (3) pages through its moments; Folio (4) shows every moment reached
  # on one page, so an unusable link must stop it before the calendar.
  for {theme, name} <- [{"2", "Rhythm"}, {"3", "Paper"}, {"4", "Folio"}] do
    describe "#{name}" do
      setup %{host: host} do
        host.id
        |> Profiles.get_profile()
        |> Changeset.change(booking_theme: unquote(theme))
        |> Repo.update!()

        :ok
      end

      test "names the other participants", %{conn: conn} do
        {:ok, _view, html} = live(conn, "/marco?with=michael")

        assert html =~ "Additional participants: Michael Example"
        assert html =~ "Team call"
        refute html =~ "Solo call"
      end

      test "says why a link naming an unknown participant can't be used", %{conn: conn} do
        {:ok, _view, html} = live(conn, "/marco?with=michael,nobody")

        assert html =~ "This booking link can’t be used"
        assert html =~ "One of the participants named in this link"
        refute html =~ "No meeting types available"
        refute html =~ "Team call"
      end

      test "offers no times for a meeting type that can't take guests", %{conn: conn} do
        {:ok, _view, html} = live(conn, "/marco/solo-call?with=michael")

        assert html =~ "This meeting type can’t be booked together with other participants."
        refute html =~ ~s(id="when-step")
        refute html =~ ~s(data-testid="paper-schedule")
      end
    end
  end
end
