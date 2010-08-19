require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe MessagesController do
  before do
    @user = mock(User, :update_attribute => true,:id=>1)
    controller.stub!(:current_user).and_return(@user)
    controller.stub!(:owned_by_user).and_return(true)
    controller.stub!(:user_check).and_return(true)
    controller.stub!(:current_server).and_return(@server)
    @user = Factory.create(:character)
    
    @user = Factory.create(:message_user,
                            :email=>"user@email.com",
                            :real_name=>"testuser")
    @recipient_1 = Factory.create(:msg_user,
                                  :name=>"recipient_1",
                                  :user =>@user )
                                  
    @recipient_2 = Factory.create(:msg_user,
                                  :name=>"recipient_2",
                                  :user =>@user )
    @msg = Message.new(
      :subject => "first msg",
      :body => "hello world"
      )
    @msg.author = @user
    @msg.to_users = "#{@recipient_1.id},#{@recipient_2.id}"
    @msg.save!
    controller.stub!(:current_user).and_return(@recipient_1)
  end

  it " index " do
    get :index, :user_id=>@user.id, :user_id => @recipient_1.id
    assigns[:folder].should be_kind_of(Object)
    assigns[:inbox_design].should_not be_nil
    assigns[:messages].should_not be_nil
  end

  it " show " do
    get :show, :id=>@msg.message_copies.first.id
    assigns[:thread].should_not be_nil
    assigns[:root_id].should_not be_nil
    assigns[:parent_message_id].should_not be_nil
    assigns[:thread].should be_kind_of(Object)
  end
  
  it " new " do
    get :new, :msg=>"hello world"
    assigns[:message].should_not be_nil
    assigns[:message].body.should == "hello world"
  end
  
  it " new message with item " do
    @item = Factory.create(:civilized_shoulders)
    get :new, :item_id=>@item.id
    assigns[:message].should_not be_nil
    assigns[:message].subject.should ==  @item.name
  end

  it " new message to unregistered recipient" do
    Character.should_receive(:find_by_id).and_return(@recipient_1)
    @recipient_1.should_receive(:unregistered?).and_return(true)
    get :new, :user_id => @recipient_1.id
    flash[:notice].should == "#{@recipient_1.name} does not have an email account set up on Zugslist. Please contact #{@recipient_1.name} in game."
    response.should redirect_to(:action => "index")
  end

  it " create a message " do
    post :create, :message=>{:body=>"Hello",:subject=>"Avtar",:to_users=>"#{ @recipient_1.id}"}
    flash[:notice].should == "Message was successfully created."
    response.should redirect_to(messages_url+'?folder=outbox')
  end


  it " reply to message " do
    post :reply, :message=>{:body=>"Hello2",:subject=>"Avtar2",
                            :to_users=>"#{ @recipient_2.id}"},
                  :parent_msg=>@msg.message_copies.first.id
    response.should redirect_to(messages_url+"/#{@msg.message_copies.first.id}")
  end
  
  it " reply to message without mesasge thread " do
    post :reply, :message=>{:body=>"Hello2",:subject=>"Avtar2",
                            :to_users=>"#{ @recipient_2.id}"}
    flash[:error].should == "No message thread found!"
    response.should redirect_to(messages_url)
    
  end


end
