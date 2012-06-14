jQuery(document).ready(function(){
	// Show error upon loading
	$('.field_with_errors').each(function(){
		$(this).children().eq(0).blur();
	})
	
	// Disable enter key on fields
	$('select, input[type=text], input[type=password], input[type=email]').live('keypress', function(e){
	    if(e.which == 13) return false;
	});
	
	$('.rule_form .title').live('click', function(){
	  $(this).parents('.rule_form').children('.settings').slideToggle();
	})
	
	$('.edit_question_show_loading').live('click',function(){
	  $('#create_question_form').hide();
	  $('#question_form').hide();
	  $('#saving').hide();
	  $('#loading').slideDown();
	})
	
	$('#cancel_edit_survey_question').live('click',function(){
	  $('#create_question_form').slideUp();
	  $('#question_form').slideUp();
	  $('#loading').hide();
	  $('#saving').hide();
	})
	
	$('#save_edit_survey_question').live('click',function(){
	  $('#create_question_form').hide();
	  $('#question_form').hide();
	  $('#loading').hide();
	  $('#saving').slideDown();
	})
	
	$('.assign_to_radio').live('click',function(){
	  type = $(this).attr('data-label');
	  $("#autoassign_suggestion .label label").html("Select " + type + ": ");
	  $("#autoassign_suggestion").slideDown();
	})
	
})