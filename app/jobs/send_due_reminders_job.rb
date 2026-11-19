class SendDueRemindersJob < ApplicationJob
  def perform
    Reminder.due.find_each do |reminder|
      DeliverReminderJob.perform_later(reminder)
    end
  end
end
