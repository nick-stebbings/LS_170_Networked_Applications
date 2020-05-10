// app.js
$(function() {
    $('form.duplicate').submit(function(event) {
      event.preventDefault();
      event.stopPropagation();
      var new_name = window.prompt("Please enter the name for the duplicate file.", $(this).find('button').val());
      if (new_name) {
        $(this).find('#new_filename').val(new_name)
        this.submit();
      }
    });
});