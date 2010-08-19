require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe MessageCopy do
  before(:each) do
    @user = Factory.create(:message_user,
                            :email=>"user@email.com",
                            :real_name=>"recipient_2")
    @user1 = Factory.create(:msg_user,
                                  :name=>"recipient_1",
                                  :user =>@user )
    @user2 = Factory.create(:msg_user,
                                  :name=>"recipient_2",
                                  :user =>@user )
    @author = Factory.create(:msg_user,
                                  :name=>"author",
                                  :user =>@user )
    
    @msg = Message.new(
      :subject => "first msg",
      :body => "hello world"
    )
    @msg.author = @author
    @msg.to_users = "#{@user1.id}, #{@user2.id}"
    @msg.save!
  end
  
  it "should set status of a new message to unread via MessageCopy" do
    @user1.inbox.messages.each {
      |msg|     
      msg.status.should == "unread"
    }
  end
  
  it "should display the details of a message" do
    @user1.inbox.messages.each {
      |msg|     
      msg.author.user.email.should == "user@email.com"
      msg.subject.should == "first msg"
      msg.body.should == "hello world"
      msg.recipients.collect(&:name).should == ["recipient_1", "recipient_2"]
    }
  end
  
  it "should mark message as read" do
    @user1.inbox.messages.each {
      |msg|     
      msg.status.should == "unread"
      msg.mark_as_read
      msg.status.should == "read"
    }
  end
  
end
