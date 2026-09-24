%% Copyright (c) 2026 Cedric Cannard. GPL-3.0 (see the repository LICENSE).

function c = galea_cellstr(c)
%GALEA_CELLSTR  A label, a cell of labels, or empty -> a cell row of labels.
%
%   >> c = galea_cellstr('tire_pop')                 % {'tire_pop'}
%   >> c = galea_cellstr({'tire_pop','no_tire_pop'})
%   >> c = galea_cellstr([])                         % {}
%
% Empty entries are dropped.
%
% Cedric Cannard, 2026

if isempty(c), c = {}; return; end
if ischar(c) || isstring(c), c = cellstr(c); end
c = c(~cellfun(@isempty, c));
c = c(:)';
end
