% LoadStromSpionSecrets.m
% Loads the secrets from StromSpionSecrets.dat located in the parent folder.

% Define the path to the secrets file in the parent folder
secrets_file = fullfile('..', 'StromSpionSecrets.dat');

% Check if the file exists before attempting to load
if exist(secrets_file, 'file') == 2
    load(secrets_file);
    disp('Successfully loaded StromSpionSecrets.dat from the parent folder.');
else
    error(['Secrets file not found: ', secrets_file, '. Please run CreateStromSpionSecrets.m in the parent folder first.']);
end
