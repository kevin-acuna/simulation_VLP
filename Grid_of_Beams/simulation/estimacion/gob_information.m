function metrics = gob_information(m,points,n,dimensions,gainMode)
if nargin<3, n = gob_noise(); end
if nargin<4, dimensions = 3; end
if nargin<5, gainMode = 'known'; end
assert(ismember(dimensions,[2,3]) && ismember(string(gainMode),["known","common","per_state"]),'gob:Information','Invalid information mode.');
N = size(points,2); d = dimensions;
metrics = struct('peb',zeros(1,N),'axis_std',zeros(d,N),'singular',zeros(d,N), ...
    'rank',zeros(1,N),'condition',zeros(1,N),'visible_5sigma',zeros(1,N),'max_power',zeros(1,N));
for first = 1:512:N
    ids = first:min(N,first+511); count = numel(ids);
    [P,J] = gob_power(m,points(:,ids)); sigma = gob_sigma(P,n);
    Jw = J(:,1:d,:)./reshape(sigma,m.n_channels,1,count);
    if ~strcmp(gainMode,'known')
        groups = {true(m.n_channels,1)};
        if strcmp(gainMode,'per_state')
            groups = arrayfun(@(k)m.state_ids==k,1:numel(m.config.radii),'UniformOutput',false);
        end
        for k = 1:numel(groups)
            mask = groups{k}; g = P(mask,:)./sigma(mask,:);
            norm2 = sum(g.^2,1); gp = reshape(g,sum(mask),1,count);
            projection = sum(gp.*Jw(mask,:,:),1)./reshape(max(norm2,1e-300),1,1,count);
            Jw(mask,:,:) = Jw(mask,:,:)-gp.*projection;
        end
    end
    [~,S,V] = pagesvd(Jw,'econ'); singular = zeros(d,count);
    for j = 1:d
        singular(j,:) = reshape(S(j,j,:),1,count);
    end
    identifiable = singular(d,:)>1e-9*singular(1,:) & singular(d,:)>1e-12;
    variance = reshape(sum(V.^2./reshape(max(singular.^2,1e-300),1,d,count),2),d,count);
    variance(:,~identifiable) = Inf;
    metrics.peb(ids) = sqrt(sum(variance,1)); metrics.axis_std(:,ids) = sqrt(variance);
    metrics.singular(:,ids) = singular;
    metrics.rank(ids) = sum(singular>1e-9*singular(1,:) & singular>1e-12,1);
    metrics.condition(ids) = singular(1,:)./max(singular(end,:),1e-300);
    metrics.visible_5sigma(ids) = sum(P>5*sigma,1);
    metrics.max_power(ids) = max(P,[],1);
end
end
