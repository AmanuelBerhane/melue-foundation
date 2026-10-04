# frozen_string_literal: true

# Serializer for InternalStudentNote (FR-135)
class InternalStudentNoteSerializer
  def initialize(note_or_collection)
    @note_or_collection = note_or_collection
  end

  def as_json(*_args)
    if @note_or_collection.respond_to?(:map)
      @note_or_collection.map { |note| serialize_single(note) }
    elsif @note_or_collection
      serialize_single(@note_or_collection)
    else
      nil
    end
  end

  private

  def serialize_single(note)
    author = note.author
    author_profile = author&.staff_member

    {
      id: note.id,
      student_id: note.student_id,
      author_id: note.author_id,
      author_name: author_profile&.full_name || author&.email || "Unknown Author",
      author_role: author&.primary_role&.name || author&.role&.to_s&.titleize || "Staff",
      content: note.content,
      internal_flag: note.internal_flag,
      recorded_at: note.recorded_at.iso8601,
      created_at: note.created_at.iso8601
    }
  end
end
