defmodule TymeslotWeb.Dashboard.MeetingTypeFormDurationsTest do
  @moduledoc """
  Round-trips the further durations of a meeting type through the real edit
  form: the "+" adds a column, the trash icon removes it, a changed value
  persists, and the total stays within the per-type maximum.
  """

  use TymeslotWeb.LiveCase, async: true

  @moduletag :meeting_types
  @moduletag :live

  import Tymeslot.DashboardTestHelpers
  import Tymeslot.Factory

  alias Tymeslot.MeetingTypes
  alias Tymeslot.Validation.Constraints

  setup :setup_dashboard_user

  defp open_edit_form(view, meeting_type) do
    view
    |> element("[phx-click='edit_type'][phx-value-id='#{meeting_type.id}']")
    |> render_click()
  end

  defp stored(meeting_type, user),
    do: MeetingTypes.get_meeting_type(meeting_type.id, user.id).extra_durations_minutes

  test "the + adds a further duration and saves it", %{conn: conn, user: user} do
    meeting_type = insert(:meeting_type, user: user, duration_minutes: 30)

    {:ok, view, _html} = live(conn, ~p"/dashboard/meeting-settings")
    open_edit_form(view, meeting_type)

    view |> element("[data-testid='add-duration']") |> render_click()

    assert has_element?(view, "[data-testid='extra-duration']")
    # The new column starts with the next common length above the longest one.
    assert stored(meeting_type, user) == [45]
  end

  test "changing a further duration saves the new value", %{conn: conn, user: user} do
    meeting_type =
      insert(:meeting_type, user: user, duration_minutes: 30, extra_durations_minutes: [60, 90])

    {:ok, view, _html} = live(conn, ~p"/dashboard/meeting-settings")
    open_edit_form(view, meeting_type)

    view
    |> element(~s|input[name="meeting_type[extra_durations][1]"]|)
    |> render_change(%{"meeting_type" => %{"extra_durations" => %{"1" => "120"}}})

    assert stored(meeting_type, user) == [60, 120]
  end

  test "the trash icon removes that column only", %{conn: conn, user: user} do
    meeting_type =
      insert(:meeting_type, user: user, duration_minutes: 30, extra_durations_minutes: [60, 90])

    {:ok, view, _html} = live(conn, ~p"/dashboard/meeting-settings")
    open_edit_form(view, meeting_type)

    view
    |> element("[data-testid='remove-duration'][phx-value-index='0']")
    |> render_click()

    assert stored(meeting_type, user) == [90]
  end

  test "a repeated duration is refused and not saved", %{conn: conn, user: user} do
    meeting_type =
      insert(:meeting_type, user: user, duration_minutes: 30, extra_durations_minutes: [60])

    {:ok, view, _html} = live(conn, ~p"/dashboard/meeting-settings")
    open_edit_form(view, meeting_type)

    view
    |> element(~s|input[name="meeting_type[extra_durations][0]"]|)
    |> render_change(%{"meeting_type" => %{"extra_durations" => %{"0" => "30"}}})

    assert has_element?(view, "[data-testid='extra-durations-error']")
    assert stored(meeting_type, user) == [60]
  end

  test "no + is offered once the maximum is reached", %{conn: conn, user: user} do
    extras =
      Enum.take([15, 45, 60, 90, 120, 150, 180], Constraints.max_durations_per_meeting_type() - 1)

    meeting_type =
      insert(:meeting_type, user: user, duration_minutes: 30, extra_durations_minutes: extras)

    {:ok, view, _html} = live(conn, ~p"/dashboard/meeting-settings")
    open_edit_form(view, meeting_type)

    refute has_element?(view, "[data-testid='add-duration']")
  end
end
