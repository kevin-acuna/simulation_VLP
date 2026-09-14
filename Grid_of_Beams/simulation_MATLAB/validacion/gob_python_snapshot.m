function snapshot = gob_python_snapshot(pythonRoot)
files = dir(fullfile(pythonRoot,'**','*'));
files = files(~[files.isdir]);
paths = strings(numel(files),1); hashes = paths;
for k = 1:numel(files)
    path = fullfile(files(k).folder,files(k).name);
    paths(k) = string(extractAfter(path,numel(pythonRoot)+1));
    digest = java.security.MessageDigest.getInstance('SHA-256');
    fid = fopen(path,'rb');
    assert(fid>=0,'gob:Snapshot','Cannot read %s',path);
    cleanup = onCleanup(@()fclose(fid));
    while ~feof(fid)
        bytes = fread(fid,1048576,'*uint8');
        digest.update(typecast(bytes,'int8'));
    end
    hashes(k) = lower(string(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[])));
    clear cleanup
end
snapshot = sortrows(table(paths,hashes),'paths');
end
