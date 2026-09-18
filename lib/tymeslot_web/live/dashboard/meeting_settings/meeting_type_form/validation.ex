defmodule TymeslotWeb.Dashboard.MeetingSettings.MeetingTypeForm.Validation do
  @moduledoc "Field-level and reminder validation helpers for MeetingTypeForm."

  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.MeetingTypes.InputValidation, as: MeetingSettingsInputValidation
  alias Tymeslot.Utils.ReminderUtils

  @doc "Validates a single named field and returns the updated `{data, errors}` tuple."
  @spec validate_and_update_field(String.t(), any(), map(), map(), map()) :: {map(), map()}
  def validate_and_update_field("name", value, metadata, acc_data, acc_errors) do
    case MeetingSettingsInputValidation.validate_field(:name, value, metadata) do
      {:ok, sanitized} -> {Map.put(acc_data, "name", sanitized), Map.delete(acc_errors, :name)}
      {:error, %{name: msg}} -> {acc_data, Map.put(acc_errors, :name, msg)}
    end
  end

  def validate_and_update_field("duration", value, metadata, acc_data, acc_errors) do
    {data, errors} =
      case MeetingSettingsInputValidation.validate_field(:duration, value, metadata) do
        {:ok, sanitized} ->
          {Map.put(acc_data, "duration", sanitized), Map.delete(acc_errors, :duration)}

        {:error, %{duration: msg}} ->
          {acc_data, Map.put(acc_errors, :duration, msg)}
      end

    # A new primary duration can collide with, or stop colliding with, one of
    # the further durations.
    revalidate_extra_durations(data, errors, metadata)
  end

  def validate_and_update_field("extra_durations", value, metadata, acc_data, acc_errors) do
    data =
      Map.put(
        acc_data,
        "extra_durations",
        MeetingSettingsInputValidation.extra_durations_list(value)
      )

    revalidate_extra_durations(data, acc_errors, metadata)
  end

  def validate_and_update_field("slot_interval", value, metadata, acc_data, acc_errors) do
    case MeetingSettingsInputValidation.validate_field(:slot_interval, value, metadata) do
      {:ok, sanitized} ->
        {Map.put(acc_data, "slot_interval", sanitized), Map.delete(acc_errors, :slot_interval)}

      {:error, %{slot_interval: msg}} ->
        {acc_data, Map.put(acc_errors, :slot_interval, msg)}
    end
  end

  def validate_and_update_field("description", value, metadata, acc_data, acc_errors) do
    case MeetingSettingsInputValidation.validate_field(:description, value, metadata) do
      {:ok, sanitized} ->
        {Map.put(acc_data, "description", sanitized), Map.delete(acc_errors, :description)}

      {:error, %{description: msg}} ->
        {acc_data, Map.put(acc_errors, :description, msg)}
    end
  end

  def validate_and_update_field(_other, _value, _metadata, acc_data, acc_errors),
    do: {acc_data, acc_errors}

  @doc "Validates a new reminder and returns `{:ok, reminder}` or `{:error, message}`."
  @spec validate_new_reminder(list(), any(), any()) :: {:ok, map()} | {:error, String.t()}
  def validate_new_reminder(reminders, value, unit) do
    cond do
      is_nil(value) or value == "" ->
        {:error, dgettext("dashboard_meeting_form", "Reminder value is required")}

      length(reminders) >= 3 ->
        {:error, dgettext("dashboard_meeting_form", "You can configure up to 3 reminders")}

      match?({:error, _reason}, ReminderUtils.validate_reminder_value(value)) ->
        {:error, dgettext("dashboard_meeting_form", "Reminder value must be a positive number")}

      unit not in ["minutes", "hours", "days"] ->
        {:error, dgettext("dashboard_meeting_form", "Select a valid reminder unit")}

      reminder_exists?(reminders, value, unit) ->
        {:error, dgettext("dashboard_meeting_form", "This reminder already exists")}

      true ->
        {:ok, %{value: ReminderUtils.parse_reminder_value(value), unit: unit}}
    end
  end

  @doc """
  Checks the further durations in `data` against the primary one and updates
  the `:extra_durations` error.
  """
  @spec revalidate_extra_durations(map(), map(), map()) :: {map(), map()}
  def revalidate_extra_durations(data, errors, metadata) do
    value = {Map.get(data, "extra_durations", []), Map.get(data, "duration")}

    case MeetingSettingsInputValidation.validate_field(:extra_durations, value, metadata) do
      {:ok, _sanitized} -> {data, Map.delete(errors, :extra_durations)}
      {:error, %{extra_durations: msg}} -> {data, Map.put(errors, :extra_durations, msg)}
    end
  end

  # --- Private helpers ---

  defp reminder_exists?(reminders, value, unit) do
    reminder_value = ReminderUtils.parse_reminder_value(value)
    new_reminder = %{value: reminder_value, unit: unit}

    ReminderUtils.duplicate_reminders?(reminders ++ [new_reminder])
  end
end
