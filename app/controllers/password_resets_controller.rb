class PasswordResetsController < ApplicationController

  before_filter :load_user_using_perishable_token, :only => [:edit, :update]  
  before_filter :require_no_user
  
  def new
  end
  
  def index
    render :action => 'new'
  end
  
  def create  
    @user = User.find_by_email(params[:email])  
    if @user  
      @user.deliver_password_reset_instructions!  
      @action = t('password_resets.new.your_password_will_not_be_changed')
      render 'shared/confirmation_sent'
    else  
      flash[:error] = t('password_resets.new.no_user_found_with_email')
      render :action => :new  
    end  
  end
  
  def edit    
  end
  
  def update
    @user.ignore_blank_passwords = false
    @user.password = params[:user][:password]  
    @user.password_confirmation = params[:user][:password_confirmation]  
    if @user.save  
      flash[:notice] = t('password_resets.edit.password_updated')
      redirect_back_or_default root_path
    else  
      render :action => :edit  
    end
  end
  
  private
  
  def load_user_using_perishable_token 
    # not currently using a timeout on the tokens
    @user = User.find_using_perishable_token(params[:id], token_age=0)  
    unless @user && @user.registered?
      flash[:error] = t('password_resets.edit.could_not_find_account')
      redirect_to root_url  
    end
    if @user && @user.suspended? # disallow attempts to reset passwords from suspended acccounts
      flash[:error] = t('shared.suspended.forbidden')
      redirect_to root_url
    end        
  end
  
end
