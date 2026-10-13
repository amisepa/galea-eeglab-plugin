%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function ok = galea_ensure_brainbeats()
% GALEA_ENSURE_BRAINBEATS  Make sure the BrainBeats extension is usable.
%
%   >> ok = galea_ensure_brainbeats()
%
% Returns true when brainbeats_process is callable by the end of the call.
% Downloads and installs BrainBeats if needed; see galea_ensure_plugin.
%
% Cedric Cannard, 2026

ok = galea_ensure_plugin('BrainBeats', 'brainbeats_process');
end
