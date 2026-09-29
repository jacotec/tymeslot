defmodule Tymeslot.Repo.Migrations.AddHostNoteToMeetings do
  use Ecto.Migration

  # The note a host writes when creating a meeting from the dashboard.
  #
  # It needs a column of its own because neither of the fields it could have
  # shared identifies its author: `attendee_message` holds the attendee's words,
  # and telling the two apart by a missing `meeting_type_id` breaks when a
  # meeting type is deleted (`on_delete: :nilify_all`), which would hand a
  # booker's private note to every co-guest. `description` carries the meeting
  # type's own text on a booked meeting, so a note read from there shows
  # internal copy as if the host had written it for the guest.
  #
  # Named `host_note` rather than `organizer_note`, which upstream is adding
  # for the same purpose: this way both can exist, and adopting theirs is a
  # data copy rather than a failed migration.
  def change do
    alter table(:meetings) do
      add :host_note, :text
    end
  end
end
