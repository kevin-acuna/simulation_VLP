function [T, files] = df_load_master(dataFile)
% DF_LOAD_MASTER  Read one or more sub3_spatial master.csv into a typed table.
%
%   T          = df_load_master(dataFile)
%   [T, files] = df_load_master(dataFile)
%
% dataFile may be
%   * a char/string path to a single master.csv, or
%   * a cell array / string array of master.csv paths.
% When several files are supplied their rows are vertically concatenated so
% the campaign can be analysed as ONE dataset. Two bookkeeping columns are
% appended to identify the origin of every row:
%   session      (string)  parent-folder name of the source master.csv
%   session_idx  (double)  1-based position of the file in the input list
%
% Text columns (point_id, scan_kind, date, time) are read as char; every
% other column is read as double. Voltage columns that contain 'NA'
% (acquisition failures) become NaN so bad rows can be filtered out later.

    files = local_to_filelist(dataFile);
    assert(~isempty(files), 'df_load_master: no data file provided.');

    parts = cell(1, numel(files));
    for i = 1:numel(files)
        f = files{i};
        assert(isfile(f), 'master.csv not found: %s', f);

        opts = detectImportOptions(f, 'Delimiter', ',', 'NumHeaderLines', 0);

        textCols = intersect({'point_id','scan_kind','date','time'}, opts.VariableNames);
        if ~isempty(textCols)
            opts = setvartype(opts, textCols, 'char');
        end

        numCols = setdiff(opts.VariableNames, textCols);
        if ~isempty(numCols)
            opts = setvartype(opts, numCols, 'double');
            opts = setvaropts(opts, numCols, 'TreatAsMissing', {'NA','na','NaN'});
        end

        Ti = readtable(f, opts);
        Ti.session     = repmat(string(local_session_name(f)), height(Ti), 1);
        Ti.session_idx = repmat(i, height(Ti), 1);
        parts{i} = Ti;
    end

    if numel(parts) == 1
        T = parts{1};
    else
        T = local_vertcat_aligned(parts);
    end
end

% =========================== local helpers ===============================
function files = local_to_filelist(dataFile)
    if ischar(dataFile)
        files = {dataFile};
    elseif isstring(dataFile)
        files = cellstr(dataFile(:).');
    elseif iscell(dataFile)
        files = cellfun(@char, dataFile(:).', 'UniformOutput', false);
    else
        error('df_load_master:badInput', ...
              'dataFile must be a path or a list of paths (cell/string array).');
    end
end

function s = local_session_name(f)
    d = fileparts(f);
    if isempty(d), s = f; return; end
    [~, name, ext] = fileparts(d);
    s = [name ext];
    if isempty(s), s = d; end
end

function T = local_vertcat_aligned(parts)
    vn = parts{1}.Properties.VariableNames;
    for i = 2:numel(parts)
        vni = parts{i}.Properties.VariableNames;
        assert(isequal(sort(vn), sort(vni)), ...
            'df_load_master: column mismatch between master.csv files (item %d).', i);
        parts{i} = parts{i}(:, vn);   % align column order before stacking
    end
    T = vertcat(parts{:});
end
