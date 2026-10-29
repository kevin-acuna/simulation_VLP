function S = pp_read_npz(file)
% Reads a NumPy .npz archive (uncompressed or deflated zip of .npy arrays) into a struct of arrays.
% Supported dtypes: u1, u2, i2, i4, i8, f4, f8 (little endian), C or Fortran order.
folder = tempname;
mkdir(folder);
cleanup = onCleanup(@() rmdir(folder, 's'));
names = unzip(file, folder);
S = struct();
for k = 1:numel(names)
    [~, key] = fileparts(names{k});
    S.(matlab.lang.makeValidName(key)) = read_npy(names{k});
end
end

function A = read_npy(file)
fid = fopen(file, 'r', 'ieee-le');
closer = onCleanup(@() fclose(fid));
magic = fread(fid, 6, 'uint8=>char')';
assert(strcmp(magic(2:end), 'NUMPY'), 'pp_read_npz:Format', 'Not a .npy file: %s', file);
version = fread(fid, 2, 'uint8');
if version(1) == 1
    header_length = fread(fid, 1, 'uint16');
else
    header_length = fread(fid, 1, 'uint32');
end
header = fread(fid, header_length, 'uint8=>char')';
descr = regexp(header, '''descr''\s*:\s*''([^'']+)''', 'tokens', 'once');
fortran = ~isempty(regexp(header, '''fortran_order''\s*:\s*True', 'once'));
shape_text = regexp(header, '''shape''\s*:\s*\(([^\)]*)\)', 'tokens', 'once');
dims = str2num(['[' shape_text{1} ']']); %#ok<ST2NM>
types = struct('u1', 'uint8', 'u2', 'uint16', 'i2', 'int16', 'i4', 'int32', 'i8', 'int64', 'f4', 'single', ...
    'f8', 'double', 'b1', 'uint8');
code = descr{1}(end - 1:end);
assert(any(descr{1}(1) == '<|='), 'pp_read_npz:Endian', 'Big-endian arrays are not supported.');
precision = [types.(code) '=>' types.(code)];
count = prod(max(dims, 1));
if isempty(dims)
    count = 1;
end
A = fread(fid, count, precision);
if numel(dims) > 1
    if fortran
        A = reshape(A, dims);
    else
        A = permute(reshape(A, fliplr(dims)), numel(dims):-1:1);
    end
end
end
