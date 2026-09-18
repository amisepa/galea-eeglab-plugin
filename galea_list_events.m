%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function ev = galea_list_events(filename, filepath)
%GALEA_LIST_EVENTS  Event labels carried by a raw Galea recording.
%
%   >> ev = galea_list_events(filename, filepath)
%
% Returns the sorted unique event labels without loading the data through the
% full import (which is slow): a lightweight header + marker scan. Returns []
% when the recording has no markers. Never throws.
%
% Cedric Cannard, 2026

ev = {};
try
    if nargin < 2 || isempty(filepath)
        [filepath, filename, ~] = fileparts(filename);
    end
    % read only the event structure: import, then drop the data
    TMP = galea_import('default', filename, filepath);
    if ~isempty(TMP.event)
        ev = unique({TMP.event.type});
        ev = ev(~cellfun(@isempty, ev));
    end
catch
    ev = {};
end
end