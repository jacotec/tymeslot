defmodule Tymeslot.MeetingTypes.DurationsTest do
  use ExUnit.Case, async: true

  @moduletag :meeting_types

  alias Tymeslot.MeetingTypes.Durations
  alias Tymeslot.MeetingTypes.MeetingTypeSchema, as: MeetingType

  defp type(primary, extras),
    do: %MeetingType{duration_minutes: primary, extra_durations_minutes: extras}

  describe "offered/1" do
    test "is the type's own duration when it offers no others" do
      assert Durations.offered(type(30, [])) == [30]
    end

    test "treats a row predating the column (NULL) like one without extras" do
      assert Durations.offered(type(30, nil)) == [30]
    end

    test "lists every length ascending, whatever order they were entered in" do
      assert Durations.offered(type(30, [120, 15, 60])) == [15, 30, 60, 120]
    end

    test "never lists a length twice" do
      assert Durations.offered(type(30, [30, 60])) == [30, 60]
    end
  end

  describe "multiple?/1, offers?/2 and resolve/2" do
    test "a single-length type has nothing to choose" do
      refute Durations.multiple?(type(30, []))
      refute Durations.multiple?(nil)
    end

    test "a type with extras offers each of them and its own duration" do
      meeting_type = type(30, [60, 90])

      assert Durations.multiple?(meeting_type)
      assert Durations.offers?(meeting_type, 30)
      assert Durations.offers?(meeting_type, 90)
      refute Durations.offers?(meeting_type, 45)
      refute Durations.offers?(meeting_type, "60")
    end

    test "resolve keeps an offered length and falls back to the type's own otherwise" do
      meeting_type = type(30, [60])

      assert Durations.resolve(meeting_type, 60) == 60
      assert Durations.resolve(meeting_type, 45) == 30
      assert Durations.resolve(meeting_type, nil) == 30
    end
  end

  describe "parse/1" do
    test "reads the forms a length arrives in" do
      assert Durations.parse(45) == 45
      assert Durations.parse("45") == 45
      assert Durations.parse("45min") == 45
      assert Durations.parse(" 45 ") == 45
    end

    test "rejects anything else" do
      assert Durations.parse("quick-chat") == nil
      assert Durations.parse("0") == nil
      assert Durations.parse("-5") == nil
      assert Durations.parse(nil) == nil
    end
  end
end
