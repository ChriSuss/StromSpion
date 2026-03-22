# ##
# LoadStromSpionSecrets.m
# Loads the secrets from StromSpionSecrets.dat located in the parent folder.
# ##

function secrets = LoadStromSpionSecrets()
    # Define the path to the secrets file in the parent folder
    secrets_file = fullfile('..', 'StromSpionSecrets.dat');

    # Check if the file exists before attempting to load
    if exist(secrets_file, 'file') ~= 2
        disp(['Secrets file not found: ', secrets_file]);
        disp('Will now try to generate Secrets with script not maintained in GitHub.');
        run ../CreateStromSpionSecrets.m;       
    end

    secrets = load(secrets_file);
    disp('Successfully loaded StromSpionSecrets.dat from the parent folder.');
end
