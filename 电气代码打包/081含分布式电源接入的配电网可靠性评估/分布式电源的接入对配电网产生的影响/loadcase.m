function [baseMVA, bus, gen, branch, areas, gencost, info] = loadcase(casefile)
%LOADCASE   Load .m or .mat case files or data struct in MATPOWER format
%
%   [baseMVA, bus, gen, branch, areas, gencost] = loadcase(casefile)
%   [baseMVA, bus, gen, branch, gencost] = loadcase(casefile)
%   [baseMVA, bus, gen, branch] = loadcase(casefile)
%   mpc = loadcase(casefile)
info = 0;
if nargout < 3
    return_as_struct = true;
else
    return_as_struct = false;
end
if nargout >= 5
    expect_gencost = true;
    if nargout > 5
        expect_areas = true;
    else 
        expect_areas = false;
    end
else
    expect_gencost = false;
    expect_areas = false;
end

%%-----  read data into struct  -----
if ischar(casefile)
    %% check for explicit extension
    l = length(casefile);
    if l > 2
        if strcmp(casefile(l-1:l), '.m')
            rootname = casefile(1:l-2);
            extension = '.m';
        elseif l > 4
            if strcmp(casefile(l-3:l), '.mat')
                rootname = casefile(1:l-4);
                extension = '.mat';
            end
        end
    end

    %% set extension if not specified explicitly
    if ~exist('rootname', 'var')
        rootname = casefile;
        if exist([casefile '.mat'], 'file') == 2
            extension = '.mat';
        elseif exist([casefile '.m'], 'file') == 2
            extension = '.m';
        else
            info = 2;
        end
    end
    
    %% attempt to read file
    if info == 0
        if strcmp(extension,'.mat')         %% from MAT file
            try
                s = load(rootname);
                if isfield(s, 'mpc')        %% it's a struct
                    s = s.mpc;
                else                        %% individual data matrices
                    s.version = '1';
                end
            catch
                info = 3;
            end
        elseif strcmp(extension,'.m')       %% from M file
            try                             %% assume it returns a struct
                s = feval(rootname);
            catch
                info = 4;
            end
            if info == 0 && ~isstruct(s)    %% if not try individual data matrices
                clear s;
                s.version = '1';
                if expect_gencost
                    try
                        [s.baseMVA, s.bus, s.gen, s.branch, ...
                            s.areas, s.gencost] = feval(rootname);
                    catch
                        info = 4;
                    end
                else
                    if return_as_struct
                        try
                            [s.baseMVA, s.bus, s.gen, s.branch, ...
                                s.areas, s.gencost] = feval(rootname);
                        catch
                            try
                                [s.baseMVA, s.bus, s.gen, s.branch] = feval(rootname);
                            catch
                                info = 4;
                            end
                        end
                    else
                        try
                            [s.baseMVA, s.bus, s.gen, s.branch] = feval(rootname);
                        catch
                            info = 4;
                        end
                    end
                end
            end
            if info == 4 && exist([rootname '.m'], 'file') == 2
                info = 5;
                err5 = lasterr;
            end
        end
    end
elseif isstruct(casefile)
    s = casefile;
else
    info = 1;
end

%%-----  check contents of struct  -----
if info == 0
    %% check for required fields
    if ~( isfield(s,'baseMVA') && isfield(s,'bus') && ...
            isfield(s,'gen') && isfield(s,'branch') ) || ...
            ( expect_gencost && ~isfield(s, 'gencost') ) || ...
            ( expect_areas &&   ~isfield(s,'areas') )
        info = 5;           %% missing some expected fields
        err5 = 'missing data';
    else
        %% remove empty areas if not needed
        if isfield(s, 'areas') && isempty(s.areas) && ~expect_areas
            s = rmfield(s, 'areas');
        end

        %% all fields present, copy to mpc
        mpc = s;
        if ~isfield(mpc, 'version') %% hmm, struct with no 'version' field
            if size(mpc.gen, 2) < 21    %% version 2 has 21 or 25 cols
                mpc.version = '1';
            else
                mpc.version = '2';
            end
        end
        if strcmp(mpc.version, '1')
            % convert from version 1 to version 2
            [mpc.gen, mpc.branch] = mpc_1to2(mpc.gen, mpc.branch);
            mpc.version = '2';
        end
    end
end

%%-----  define output variables  -----
if return_as_struct
    bus = info;
end

if info == 0    %% no errors
    if return_as_struct
        baseMVA = mpc;
    else
        baseMVA = mpc.baseMVA;
        bus     = mpc.bus;
        gen     = mpc.gen;
        branch  = mpc.branch;
        if expect_gencost
            if expect_areas
                areas   = mpc.areas;
                gencost = mpc.gencost;
            else
                areas = mpc.gencost;
            end
        end
    end
else            %% we have a problem captain
    if nargout == 2 || nargout == 7   %% return error code
        if return_as_struct
            baseMVA = struct([]);
        else
            baseMVA = []; bus = []; gen = []; branch = [];
            areas = []; gencost = [];
        end
    else                                            %% die on error
        switch info
            case 1,
                error('loadcase: input arg should be a struct or a string containing a filename');
            case 2,
                error('loadcase: specified case not in MATLAB''s search path');
            case 3,
                error('loadcase: specified MAT file does not exist');
            case 4,
                error('loadcase: specified M file does not exist');
            case 5,
                error('loadcase: syntax error or undefined data matrix(ices) in the file\n%s', err5);
            otherwise,
                error('loadcase: unknown error');
        end
    end
end


function [gen, branch] = mpc_1to2(gen, branch)

%% define named indices into bus, gen, branch matrices
[GEN_BUS, PG, QG, QMAX, QMIN, VG, MBASE, GEN_STATUS, PMAX, PMIN, ...
    MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN, PC1, PC2, QC1MIN, QC1MAX, ...
    QC2MIN, QC2MAX, RAMP_AGC, RAMP_10, RAMP_30, RAMP_Q, APF] = idx_gen;
[F_BUS, T_BUS, BR_R, BR_X, BR_B, RATE_A, RATE_B, RATE_C, ...
    TAP, SHIFT, BR_STATUS, PF, QF, PT, QT, MU_SF, MU_ST, ...
    ANGMIN, ANGMAX, MU_ANGMIN, MU_ANGMAX] = idx_brch;

%%-----  gen  -----
%% use the version 1 values for column names
if size(gen, 2) > APF
    error('mpc_1to2: gen matrix appears to already be in version 2 format');
end
shift = MU_PMAX - PMIN - 1;
tmp = num2cell([MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN] - shift);
[MU_PMAX, MU_PMIN, MU_QMAX, MU_QMIN] = deal(tmp{:});

%% add extra columns to gen
tmp = zeros(size(gen, 1), shift);
if size(gen, 2) >= MU_QMIN
    gen = [ gen(:, 1:PMIN) tmp gen(:, MU_PMAX:MU_QMIN) ];
else
    gen = [ gen(:, 1:PMIN) tmp ];
end

%%-----  branch  -----
%% use the version 1 values for column names
shift = PF - BR_STATUS - 1;
tmp = num2cell([PF, QF, PT, QT, MU_SF, MU_ST] - shift);
[PF, QF, PT, QT, MU_SF, MU_ST] = deal(tmp{:});

%% add extra columns to branch
tmp = ones(size(branch, 1), 1) * [-360 360];
tmp2 = zeros(size(branch, 1), 2);
if size(branch, 2) >= MU_ST
    branch = [ branch(:, 1:BR_STATUS) tmp branch(:, PF:MU_ST) tmp2 ];
elseif size(branch, 2) >= QT
    branch = [ branch(:, 1:BR_STATUS) tmp branch(:, PF:QT) ];
else
    branch = [ branch(:, 1:BR_STATUS) tmp ];
end