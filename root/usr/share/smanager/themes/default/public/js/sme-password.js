// js/sme-password.js
$(document).ready(function() {
    // For each password input
    $('.sme-password').each(function() {
        // Create a new container
        //alert("sme-password");
        var $inputContainer = $('<div class="input-container"></div>');
        
        // Move the input into the new container
        $(this).wrap($inputContainer);
        
        // Create the toggle image
        var $togglePassword = $('<img src="images/visible.png" alt="Show Password" class="toggle-password" />');
        
        // Append the toggle image to the container
        $(this).after($togglePassword);
    });

    $('.toggle-password').on('click', function() {
        // Find the associated password field
        var input = $(this).siblings('.sme-password');

        // Toggle the type attribute between password and text
        var inputType = input.attr('type') === 'password' ? 'text' : 'password';
        input.attr('type', inputType);
        
        // Toggle the icon source based on the input type
        var iconSrc = inputType === 'password' ? 'images/visible.png' : 'images/visible-slash.png';
        $(this).attr('src', iconSrc);
    });
});