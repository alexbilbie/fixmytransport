# == Schema Information
# Schema version: 20100707152350
#
# Table name: operators
#
#  id              :integer         not null, primary key
#  code            :string(255)
#  name            :text
#  created_at      :datetime
#  updated_at      :datetime
#  short_name      :string(255)
#  email           :text
#  email_confirmed :boolean
#  notes           :text
#

require 'spec_helper'

describe Operator do
  
  
  before(:each) do
    @valid_attributes = {
      :code => "value for code",
      :name => "value for name"
    }
  end

  it "should create a new instance given valid attributes" do
    operator = Operator.new(@valid_attributes)
    operator.valid?.should be_true
  end
  
  it 'should require the name attribute' do 
    operator = Operator.new(@valid_attributes)
    operator.name = nil
    operator.valid?.should be_false
  end
  
  describe 'when creating operators' do 

    it "should consider an associated route operator invalid if the attributes passed don't contain an '_add' item" do
      operator = Operator.new(@valid_attributes) 
      operator.route_operator_invalid({ "_add" => "0", 
                                        "route_id" => 44 } ).should be_true
    end
  
    it "should consider an associated route operator valid if the attributes passed contain an '_add' item whose value is 1" do 
      @valid_attributes["route_operators_attributes"] = 
      operator = Operator.create(@valid_attributes) 
      operator.route_operator_invalid({ "_add" => "1", 
                                        "route_id" => 44 }).should be_false
    end                                                    
  
  end
  
  it 'should respond to emailable? correctly' do 
    operator = Operator.new
    operator.email = "test email"
    operator.emailable?.should be_true
    operator.email = ''
    operator.emailable?.should be_false
    operator.email = nil
    operator.emailable?.should be_false
  end
  
end
