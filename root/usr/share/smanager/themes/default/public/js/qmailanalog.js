document.addEventListener('DOMContentLoaded', function() {
    const analysisType = document.getElementById('analysis_type');
    const messageIdGroup = document.getElementById('message_id_group');
    const emailAddressGroup = document.getElementById('email_address_group');

    // Initially hide both controls
    messageIdGroup.style.display = 'none';
    emailAddressGroup.style.display = 'none';

    analysisType.addEventListener('change', function() {
        // Hide both controls first
        messageIdGroup.style.display = 'none';
        emailAddressGroup.style.display = 'none';

        // Show the relevant control based on the selected option
        switch(this.value) {
            case 'trace_message':
                messageIdGroup.style.display = 'block';
                break;
            case 'user_activity':
                emailAddressGroup.style.display = 'block';
                break;
        }
    });
});