class MessageObserver < ActiveRecord::Observer
  def after_create(message)
    message.recipients.each {
      |user|
      MessageMailer.deliver_message_notification(message, user)
    }
  end
end
