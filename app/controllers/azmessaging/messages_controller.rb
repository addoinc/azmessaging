module Azmessaging

  class MessagesController < ApplicationController
    before_filter :login_required
    before_filter :user_check
    
    def index
      @folder = params[:folder] == 'inbox' ? current_user.inbox :
        params[:folder] == 'outbox' ? current_user.outbox :
        params[:folder] == 'recurring' ? current_user.recurring : current_user.inbox
      
      if @folder.name == "Outbox"
        @inbox_design = ""
        @outbox_design="message"
      elsif @folder.name == "Inbox"
        @inbox_design = "message"
        @outbox_design = ""
      end
      
      options = {
        :page => params[:page],
        :include => [:message => :author]
      }
      
      params[:order] || ""
      @order = {}
      case(params[:order])
      when "received_asc"
        options.merge!( :order => "message_copies.updated_at ASC" )
        @order.merge!( :received => "desc")
      when "received_desc"
        options.merge!( :order => "message_copies.updated_at DESC" )
        @order.merge!( :received => "asc")
      when "status_asc"
        options.merge!( :order => "message_copies.status ASC" )
        @order.merge!( :status => "desc")
      when "status_desc"
        options.merge!( :order => "message_copies.status DESC" )
        @order.merge!( :status => "asc")
      else
        options.merge!( :order => "message_copies.updated_at DESC" )
        @order.merge!( :received => "asc")
      end
      @messages = @folder.messages.paginate(options)

      respond_to do |format|
        format.html # index.html.erb
        format.xml  { render :xml => @messages }
        format.rss  { render :layout => false }
      end
    rescue StandardError => e
      logger.info( e.inspect )
      flash[:error] = "Invalid messages folder!"
      redirect_to user_path(session[:user_id]) #this needs to go to the main dashboard page, otherwise a recursive error occurs if folders are not yet setup
    end
    
    def show
      @thread = current_user.folders.find_message(params[:id]).message_thread(current_user)
      @root_id = @thread.first.root_id
      @parent_message_id = params[:id]
      @message = Message.new
      
      respond_to do |format|
        format.html # show.html.erb
        format.xml  { render :xml => @thread }
        format.rss  { render :template => "messages/show.rss.builder", :layout => false }
        format.rss  { render :template => "dashboard/messages/show.rss.builder", :layout => false }
      end
  rescue ActiveRecord::RecordNotFound => e
      flash[:error] = "No message thread found!"
      redirect_to messages_url
  end
    
    def new
      @message = Message.new(:body => params[:msg])
      
      if @item = Item.find_by_id(params[:item_id])
        @message.msg_type = "Item"
        @message.msg_id = @item.id
        @message.subject = @item.name
      end
      
      if @service = Service.find_by_id(params[:service_id])
        @message.msg_type = "Service"
        @message.msg_id = @service.id
        @message.subject = @service.title
        @message.body = "I am interested in #{@service.title}."
      end
      
      unless params[:user_id].blank?
        @recipient_user =  params[:user_id]
        @recipient = User.find_by_id(params[:user_id])
        
        if @recipient && @recipient.unregistered?
          flash[:notice] = "#{@recipient.name} does not have an email account set up on AzMessaing."
          redirect_to :action => "index"
          return
        end
      end
      
      respond_to do |format|
        format.html # new.html.erb
        format.xml  { render :xml => @message }
      end
    end
    
    def create
      # @is_admin = current_user.has_role_for_resource?(["SiteAdmin"], @subdomain_org)
      # raise StandardError, 'Access Denied' if( params[:message][:is_recur] == "1" && !@is_admin )
      @message = Message.new(params[:message])
      
    user = User.find_by_id(params[:author_id])
      user = current_user unless user && user.owned_by?(current_user)
      @message.author = user
      
      respond_to do |format|
        if @message.save
          flash[:notice] = 'Message was successfully created.'
          format.html { redirect_to( messages_url+'?folder=outbox' ) }
          format.xml  { render :xml => @message, :status => :created, :location => @message }
        else
          format.html { render :action => "new" }
          format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
        end
      end
      #rescue StandardError => e
      #  logger.info( e.inspect )
      #  flash[:error] = "Error: Permission denied!"
      #  redirect_to messages_path
    end
    
    def edit
      # @is_admin = current_user.has_role_for_resource?(["SiteAdmin"], @subdomain_org)
      # raise StandardError, 'Access Denied' if( !@is_admin )
      
      message_copy = current_user.recurring.messages.find_by_id(params[:id])
      raise ActiveRecord::RecordNotFound if ( message_copy.nil? )
      @message = message_copy.message
      
      respond_to do |format|
        format.html # edit.html.erb
      end
    rescue ActiveRecord::RecordNotFound => e
      logger.info( e.inspect )
      flash[:error] = "No message found!"
      redirect_to messages_url
    rescue StandardError => e
      logger.info( e.inspect )
      flash[:error] = "Access Denied!"
      redirect_to messages_url
    end
    
    def update
      # @is_admin = current_user.has_role_for_resource?(["SiteAdmin"], @subdomain_org)
      # raise StandardError, 'Access Denied' if( !@is_admin )
      
      message_copy = current_user.recurring.messages.find_by_id(params[:id])
      raise ActiveRecord::RecordNotFound if ( message_copy.nil? )
      @message = message_copy.message
      
      if @message.update_attributes(params[:message])
        flash[:notice] = 'Message was successfully updated.'
        redirect_to( :action => "edit", :id => params[:id] )
      else
        flash.now[:error] = "Recurring message could not be edited"
        render :action => 'edit'
      end
    rescue ActiveRecord::RecordNotFound => e
      logger.info(e.inspect)
      flash[:error] = "Message not found!"
      redirect_to messages_url
    rescue StandardError => e
      logger.info( e.inspect )
      flash[:error] = "Access Denied!"
      redirect_to messages_url
    end
    
    def reply
      @message = Message.new(params[:message])
      @message.author = current_user
      status = false
      if( !params[:parent_msg].blank? )
        begin
          parent_msg = current_user.folders.find_message(params[:parent_msg]).message
        rescue ActiveRecord::RecordNotFound => e
          flash[:error] = "No parent message thread found!"
          status = false
        else
          @message.root_id = parent_msg.root_id
          status = @message.save
          if( status )
            @message.move_to_child_of(parent_msg)
          end
        end
      end
      
      unless status
        @thread = current_user.folders.find_message(params[:parent_msg]).message_thread(current_user)
        @parent_message_id = params[:parent_msg]
        @root_id = @thread.first.root_id
      end
      
      respond_to do |format|
        if status
          flash[:notice] = 'Message was successfully created.'
          format.html { redirect_to( :action => "show", :id => params[:parent_msg] ) }
          format.xml  { render :xml => @message, :status => :created, :location => @message }
          # format.xhr { :json => @messge.to_json }
        else
          format.html { render :action => "show", :id => params[:parent_msg] }
          format.xml  { render :xml => @message.errors, :status => :unprocessable_entity }
          # format.xhr { :json => @messge.to_json }
        end
      end
    rescue ActiveRecord::RecordNotFound => e
      flash[:error] = "No message thread found!"
      redirect_to messages_url
    end
    
    def markread
      message = current_user.folders.find_message_for_update(params[:id])
      message.mark_as_read
      if message.save
        render :partial => "message", :locals => { :message => message }, :layout => false
      else
        render :text => "ERROR", :layout => false, :status => 500
      end
    rescue ActiveRecord::RecordNotFound => e
      render :text => "Error: No record found", :layout => false, :status => 500
    rescue AASM::InvalidTransition => e
      render :text => "Error: message was already marked as read.", :layout => false, :status => 500
    end
    
    def markunread
      message = current_user.folders.find_message_for_update(params[:id])
      message.mark_as_unread
      if message.save
        render :partial => "message", :locals => { :message => message }, :layout => false
      else
        render :text => "ERROR", :layout => false, :status => 500
      end
    rescue ActiveRecord::RecordNotFound => e
      render :text => "Error: No record found", :layout => false, :status => 500
    rescue AASM::InvalidTransition => e
      render :text => "Error: message was already marked as unread.", :layout => false, :status => 500
    end
    
  end
  
end
