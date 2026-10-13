%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function ok = galea_ensure_plugin(name, fcn)
% GALEA_ENSURE_PLUGIN  Make sure an EEGLAB extension is usable, installing it if needed.
%
%   >> ok = galea_ensure_plugin('BrainBeats', 'brainbeats_process')
%   >> ok = galea_ensure_plugin('PICARD', 'picard')
%
%   name - extension name as listed in the EEGLAB Extension Manager
%   fcn  - a function of that extension, used to tell whether it is on the path
%
% Returns true when FCN is callable by the end of the call.
%
% Why not simply plugin_askinstall(name, ...)? EEGLAB's plugin_askinstall
% ERRORS ("Cannot find ... extension, use EEGLAB Extension Manager to install
% it") when the call stack is deeper than two frames, which is always the case
% when called from inside another plugin's processing chain. This helper
% therefore:
%   1. returns early if the extension is already on the path;
%   2. looks for an installed-but-not-on-path copy under eeglab/plugins and
%      adds it (covers the "installed but deactivated / path lost" case);
%   3. otherwise downloads and installs it through the same EEGLAB mechanism
%      the Extension Manager uses (plugin_getweb + plugin_install), printing
%      progress to the console;
%   4. adds the newly installed folder to the path.
%
% Cedric Cannard, 2026

ok = false;
if exist(fcn, 'file')
    ok = true; return
end

% 2. installed but not on path
if add_installed(name, fcn), ok = true; return; end

% 3. not installed: download it. plugin_askinstall cannot be used from here
%    (it errors from deep call stacks), so drive plugin_getweb/plugin_install
%    directly - this is exactly what its "download now?" branch does.
fprintf('%s is not installed. Downloading it (this needs internet)...\n', name);
try
    plugins = plugin_getweb('plugin_install', []);
    if isempty(plugins), error('extension list unavailable'); end
    ind = find(strcmpi(name, {plugins.name}), 1);
    if isempty(ind), error('%s not in the extension list', name); end
    result = plugin_install(plugins(ind).zip, plugins(ind).name, plugins(ind).version, false);
    if result ~= 1, error('plugin_install returned %d', result); end
catch ME
    warning(['Could not install %s automatically (%s). Install it from ' ...
        'File > Manage EEGLAB extensions, then run this step again.'], name, ME.message);
    return
end

% 4. put the fresh install on the path (plugin_install drops it in eeglab/plugins)
ok = add_installed(name, fcn);
if ~ok
    % a rebuild is sometimes needed before the new functions resolve
    rehash; rehash toolboxcache;
    ok = exist(fcn, 'file') > 0;
end
if ok, fprintf('  %s installed and ready.\n', name); end
end

% ---------------------------------------------------------------------------
function ok = add_installed(name, fcn)
% Add eeglab/plugins/<name>* to the path. The folder is matched without regard
% to case (dir patterns are case-sensitive on Linux and macOS).
ok = false;
root = fileparts(which('eeglab.m'));
cand = dir(fullfile(root, 'plugins'));
cand = cand([cand.isdir] & strncmpi({cand.name}, name, length(name)));
for c = 1:numel(cand)
    p = fullfile(cand(c).folder, cand(c).name);
    addpath(genpath(p));
    if exist(fcn, 'file')
        fprintf('  %s found in %s and added to the path.\n', name, p);
        ok = true; return
    end
end
end
