class SmsKeywordsController < ApplicationController
  before_filter :check_org_and_authorize
  before_filter :find_keyword, :only => [:edit, :update, :destroy]
  
  def index
    authorize! :manage, current_organization
    @keywords = current_organization.self_and_children_keywords
  end


  # GET /sms_keywords/new
  # GET /sms_keywords/new.xml
  def new
    session[:wizard] = true if request.referer.present? && request.referer.include?('wizard')
    @sms_keyword = SmsKeyword.new(organization: current_organization)

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @sms_keyword }
    end
  end

  # GET /sms_keywords/1/edit
  def edit
  end

  # POST /sms_keywords
  # POST /sms_keywords.xml
  def create
    @sms_keyword = current_user.sms_keywords.new(params[:sms_keyword])
    @sms_keyword.organization_id ||= current_organization.id
    @sms_keyword.user = current_user

    respond_to do |format|
      if @sms_keyword.save
        format.html { redirect_to(session[:wizard] && wizard_path ? wizard_path : sms_keywords_path) } #, notice: t('sms_keywords.flash.created')
        format.xml  { render xml: @sms_keyword, status: :created, location: @sms_keyword }
      else
        format.html { render action: "new" }
        format.xml  { render xml: @sms_keyword.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /sms_keywords/1
  # PUT /sms_keywords/1.xml
  def update
    respond_to do |format|
      if @sms_keyword.update_attributes(params[:sms_keyword])
        format.html { redirect_to(sms_keywords_path, notice: t('sms_keywords.flash.updated')) }
        format.xml  { head :ok }
      else
        format.html { render action: "edit" }
        format.xml  { render xml: @sms_keyword.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sms_keywords/1
  # DELETE /sms_keywords/1.xml
  def destroy
    @sms_keyword.destroy

    respond_to do |format|
      format.html { redirect_to sms_keywords_path, notice: t('sms_keywords.keyword_deleted') }
      format.xml  { head :ok }
    end
  end
  
  def accept_twilio
    current_organization.keywords.update_all("gateway = 'twilio'")
    redirect_to :back
  end
  
  private
    def check_org_and_authorize
      unless current_organization
        session[:return_to] = params
        redirect_to wizard_path || user_root_path
        return false
      end
      authorize! :manage, current_organization
    end
    
    def find_keyword
      @sms_keyword = SmsKeyword.find(params[:id])
      authorize! :manage, @sms_keyword
    end
end
