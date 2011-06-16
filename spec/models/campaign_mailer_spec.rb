require 'spec_helper'

describe CampaignMailer do
  
  describe 'when receiving mail' do 
    
    before do
      filepath = File.join(RAILS_ROOT, 'spec', 'examples', 'email', "plain.txt")
      @raw_email = File.read(filepath)
      @mock_user = mock_model(User, :name_and_email => "Campaign Person <campaign.person@my-campaign.example.com>",
                                    :name => "Campaign Person")
      @mock_campaign = mock_model(Campaign, :get_recipient => @mock_user,
                                            :title => "A Test Campaign")
      @mock_message = mock_model(IncomingMessage)
      IncomingMessage.stub!(:create_from_tmail).and_return(@mock_message)
    end
  
    describe 'if a campaign address can be found in the to: field' do 
      
      before do
        Campaign.stub!(:find_by_campaign_email).with('campaign.person@my-campaign.example.com').and_return(@mock_campaign)
      end
      
      it 'should create an incoming message for the campaign from the mail' do 
        IncomingMessage.should_receive(:create_from_tmail).with(anything, @raw_email, @mock_campaign).and_return(@mock_message)
        CampaignMailer.receive(@raw_email)
      end
      
      it 'should send a message to the recipient telling them they have a message' do 
        CampaignMailer.should_receive(:deliver_new_message).with(@mock_user, @mock_message, @mock_campaign)
        CampaignMailer.receive(@raw_email)
      end
      
    end
    
    describe 'if no campaign address can be found' do 
    
      before do
        Campaign.stub!(:find_by_campaign_email).and_return(nil)
      end
      
      it 'should create an incoming message with no associated campaign' do 
        IncomingMessage.should_receive(:create_from_tmail).with(anything, @raw_email, nil)
        CampaignMailer.receive(@raw_email)
      end
      
    end
     
  end
  
  describe 'when sending a campaign update' do 
  
    describe 'when not running in dry-run mode' do 
          
      before do
        CampaignMailer.stub!(:dry_run).and_return(false) 
        CampaignMailer.stub!(:sent_count).and_return(0)
        SentEmail.stub!(:find).and_return([])
        SentEmail.stub!(:create!)
        @mock_user = mock_model(User, :email => 'supporter@example.com', 
                                      :name => 'Supporter',
                                      :name_and_email => 'Supporter <supporter@example.com>')
        @mock_update_user = mock_model(User, :name => 'Update Sender',
                                             :first_name => 'Update')
        @mock_supporter = mock_model(CampaignSupporter, :supporter => @mock_user, 
                                                        :token => 'mytoken')
        @mock_supporter_association = mock('supporter association', :confirmed => [@mock_supporter])
        @mock_campaign = mock_model(Campaign, :campaign_supporters => @mock_supporter_association,
                                              :title => "A test campaign",
                                              :description => 'Some description')
        @mock_update = mock_model(CampaignUpdate, :campaign => @mock_campaign, 
                                                  :user => @mock_update_user,
                                                  :update_attribute => true, 
                                                  :incoming_message => nil,
                                                  :outgoing_message => nil,
                                                  :text => 'an update', 
                                                  :is_advice_request? => false)
      end
      
      it 'should create a sent email model for each update email sent' do 
        SentEmail.should_receive(:create!).with(:recipient => @mock_user, 
                                                :campaign => @mock_campaign, 
                                                :campaign_update => @mock_update)
        CampaignMailer.send_update(@mock_update, @mock_campaign)
      end
    
      it 'should send an advice request email and an expert advice request mail if the update is an advice request' do 
        @mock_update.stub!(:is_advice_request?).and_return(true)
        ActionMailer::Base.deliveries.clear
        CampaignMailer.send_update(@mock_update, @mock_campaign)
        ActionMailer::Base.deliveries.size.should == 2
        expert_mail = ActionMailer::Base.deliveries.first
        expert_mail.body.should match(/Hi transport experts/)
        expert_mail.body.should match(/would like some advice/)    
        expert_mail.body.should_not match(/stop receiving update/) 
       
        supporter_mail = ActionMailer::Base.deliveries.second
        supporter_mail.body.should match(/Hi Supporter/)
        supporter_mail.body.should match(/would like some advice/)
        supporter_mail.body.should match(/stop receiving updates/) 
      end
    
      it 'should not send an email to a recipient who has already received an email for this update' do 
        mock_sent_email = mock_model(SentEmail, :recipient => @mock_user)
        SentEmail.stub!(:find).and_return([mock_sent_email])
        CampaignMailer.should_not_receive(:deliver_update)
        CampaignMailer.send_update(@mock_update, @mock_campaign)
      end
      
      it 'should not send an email to the person who created the update' do 
        @mock_supporter.stub!(:supporter).and_return(@mock_update_user)
        CampaignMailer.should_not_receive(:deliver_update)
        CampaignMailer.send_update(@mock_update, @mock_campaign)
      end
      
    end
    
  end

  def setup_write_to_other_data
    @campaign = mock_model(Campaign, :title => "Transport campaign")
    @user = mock_model(User, :name => 'Joe Campaign', :name_and_email => '')
    @expert = mock_model(User, :name => 'Bob Expert', 
                               :first_name => 'Bob')
    @assignment = mock_model(Assignment, :campaign => @campaign, 
                                         :user => @user, 
                                         :creator => @expert,
                                         :data => {:name => 'Ken Transport'})
    @subject = "What you should do now"
  end
  
  describe "when creating a 'write-to-other' assignment" do

    before do 
      setup_write_to_other_data
    end
    
    it "should render successfully" do
      lambda { CampaignMailer.create_write_to_other_assignment(@assignment, @subject) }.should_not raise_error
    end
    
  end
  
  describe "when delivering a 'write-to-other' assignment" do 
  
    before do 
      setup_write_to_other_data
      @mailer = CampaignMailer.create_write_to_other_assignment(@assignment, @subject)
    end
    
    it 'should deliver successfully' do
      lambda { CampaignMailer.deliver(@mailer) }.should_not raise_error
    end
    
  end
  
end