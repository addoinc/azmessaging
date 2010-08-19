xml.instruct!

xml.rss "version" => "2.0", "xmlns:dc" => "http://purl.org/dc/elements/1.1/" do
  xml.channel do
    xml.title       "AzMessaging Messages for " + current_user.login.to_s
    xml.link        url_for(:only_path => false, :controller => 'dashboard/messages')
    xml.description "AzMessaging Messages for " + current_user.login.to_s

    @messages.each do |message|
      xml.item do
        xml.title       message.subject
        xml.pubDate     message.created_at
        xml.author      message.author.login
        xml.link        url_for(:only_path => false, :controller => 'dashboard/messages', :action => 'show', :id => message.id)
        xml.description message.body
        xml.guid        url_for(:only_path => false, :controller => 'dashboard/messages', :action => 'show', :id => message.id)
      end
    end
  end
end
