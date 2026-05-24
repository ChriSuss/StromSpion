# ##
# StromSpionMain.m
# Main script for StromSpion
# ##

# Call the function to load the secrets
secrets = LoadStromSpionSecrets();

# Display the loaded secrets to verify it works
disp('Loaded secrets:');
disp(secrets);

# Load the data using the secrets
data = LoadStromSpionData(secrets);

# Refactor the data to add time of day
data = RefactorStromSpionData(data);
