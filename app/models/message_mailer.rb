class MessageMailer < ActionMailer::Base
  default_url_options[:host] = HOST
  default_url_options[:port] = PORT if defined?(PORT)

  def message_notification(message, user)
    setup_email(message, user)
    @subject    += ' New message: '
    @body[:message]  = message
  end
  
  protected
  def setup_email(message, user)
    @reply_to = message.author.user.email
    @recipients = user.user.email
    @from = "help@azmessaging"
    @subject = "AzMessaging alert"
    @sent_on = Time.now
    @body[:user] = user
   end
end
