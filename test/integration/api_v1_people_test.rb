require 'test_helper'
include ApiTestHelper

class ApiV1PeopleTest < ActionDispatch::IntegrationTest
  context "the api" do
    setup do
      setup_api_env
    end
    
    should "be able to request person information" do
       path = "/api/v1/people/#{@user3.person.id}"
       get path, {'access_token' => @access_token3.code}, {:accept => 'application/vnd.missionhub-v1+json'}
       assert_response :success, @response.body
       @json = ActiveSupport::JSON.decode(@response.body)
       
       person_full_test(@json[0], @user3, @user2)
     end
     
     should "be able to request person information with fields" do
       path = "/api/v1/people/#{@user3.person.id}"
       get path, {'access_token' => @access_token3.code, 'fields' => "first_name,last_name,name,id,birthday,fb_id,picture,gender,education,interests,id,locale,location,assignment,request_org_id,organization_membership,organizational_roles,status"}, {:accept => 'application/vnd.missionhub-v1+json'}
       assert_response :success, @response.body
       @json = ActiveSupport::JSON.decode(@response.body)
       #raise @response.body.inspect unless @json[0]
       person_full_test(@json[0], @user3, @user2)
     end
     
  end
end
