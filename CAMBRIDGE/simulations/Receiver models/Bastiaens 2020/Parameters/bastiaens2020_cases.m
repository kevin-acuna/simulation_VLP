function cases = bastiaens2020_cases(base, device, outer_fov_deg, cosine_fov_deg, families, receiver_order)
if nargin<4 || isempty(cosine_fov_deg), cosine_fov_deg=outer_fov_deg; end
if nargin<5, families={'cosine_1','cosine','SQ'}; end
if nargin<6, receiver_order=[]; end
families=cellstr(string(families));
assert(~isempty(families),'cambridge:PaperFamilies','Select at least one receiver-response model.');
items=cell(1,numel(families));
for i=1:numel(families)
    family=lower(families{i});
    cutoff=outer_fov_deg;
    switch family
        case 'cosine_1'
            id='cosine_1'; cutoff=cosine_fov_deg;
        case {'cosine','cosine_mr'}
            id='cosine_mR'; cutoff=cosine_fov_deg;
        case 'sq'
            id='paper_SQ';
        case 'sqapprox'
            id='paper_SQapprox';
        case 'exp'
            id='paper_Exp';
        otherwise
            error('cambridge:PaperFamily','Unknown receiver-response family: %s.',families{i});
    end
    p=bastiaens2020_parameters(base,device,families{i},cutoff,receiver_order);
    d=rx_receiver_description(p);
    items{i}=struct('id',id,'family',families{i},'label',char(d.Label),'parameters',p);
end
cases=[items{:}];
assert(numel(unique({cases.id}))==numel(cases),'cambridge:DuplicatePaperFamily','Select each receiver-response family only once.');
end
