function T = df_load_master(dataFile)
% DF_LOAD_MASTER  Read a sub3_spatial master.csv into a typed table.
%
%   T = df_load_master(dataFile)
%
% Text columns (point_id, scan_kind, date, time) are read as char; every
% other column is read as double. Voltage columns that contain 'NA'
% (acquisition failures) become NaN so bad rows can be filtered out later.

    assert(isfile(dataFile), 'master.csv not found: %s', dataFile);

    opts = detectImportOptions(dataFile, 'Delimiter', ',', 'NumHeaderLines', 0);

    textCols = intersect({'point_id','scan_kind','date','time'}, opts.VariableNames);
    if ~isempty(textCols)
        opts = setvartype(opts, textCols, 'char');
    end

    numCols = setdiff(opts.VariableNames, textCols);
    if ~isempty(numCols)
        opts = setvartype(opts, numCols, 'double');
        opts = setvaropts(opts, numCols, 'TreatAsMissing', {'NA','na','NaN'});
    end

    T = readtable(dataFile, opts);
end
