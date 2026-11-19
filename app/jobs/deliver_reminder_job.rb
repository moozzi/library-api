class DeliverReminderJob < ApplicationJob
  discard_on ActiveJob::DeserializationError

  retry_on StandardError, wait: 10.minutes, attempts: 3 do |job, _error|
    Reminder.pending.where(id: job.arguments.first.id).update_all(status: "failed", updated_at: Time.zone.now)
  end

  def perform(reminder)
    reminder.with_lock do
      return unless reminder.pending?

      if reminder.borrowing.returned_at.present?
        reminder.update!(status: :cancelled)
        return
      end

      Reminders::LogEmailPayload.call(reminder)
      reminder.update!(status: :sent, sent_at: Time.zone.now)
    end
  end
end
