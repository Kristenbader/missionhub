class FollowupCommentsController < ApplicationController
  def create
    @followup_comment = FollowupComment.create(params[:followup_comment])
    params[:rejoicables].each do |what|
      if Rejoicable::OPTIONS.include?(what)
        @followup_comment.rejoicables.create(what: what, created_by_id: current_person.id, person_id: @followup_comment.contact_id, organization_id: @followup_comment.organization_id)
      end
    end if params[:rejoicables]
    respond_to do |wants|
      wants.html { redirect_to :back }
      wants.js
    end
  end
  
  def destroy
    @followup_comment = FollowupComment.find(params[:id])
    @followup_comment.destroy
    render nothing: true
  end
end
