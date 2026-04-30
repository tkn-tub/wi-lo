function bits = WiFi_bits(nbIQ, header_mac, cfgNonHT, scrambler_init, DISABLE_IFS, ...
    DISABLE_BLANKING, blanksymbols, MAX_HW_BYTES, mode, overlap)
    
    arguments
        nbIQ
        header_mac
        cfgNonHT
        scrambler_init
        DISABLE_IFS
        DISABLE_BLANKING
        blanksymbols (1,1) int64 = 0
        MAX_HW_BYTES = 2304
        mode = "std"
        overlap = false
    end
    % WiFi_bits Converts a Narrowband Complex Waveform to WiFi payload bits
    %   in:     nbIQ                narrowband waveform to emulate
    %           cfgNonHT            cfgDSSS
    %           ifs                 inter-frame space between two WiFi
    %                               frames
    %           DISABLE_BLANKING    DISABLE_BLANKING
    %           ALL_SCRAM_INIT      set to true bits shall be generated with all possible scrambler seeds
    %   out:    bits            payload bits of 802.11 CCK frame
    % 
    % hard-coded to 11 Mbit/s
    
    %#codegen

    assert(isvector(nbIQ), "Narrowband IQ is not a vector");
    assert(size(nbIQ, 2) == 1, "Narrowband IQ needs dimensions N-by-1");

    % Clause 17.3.3 DS PHY characteristics
    %; %2304;
    MAX_PSDU_BYTES = MAX_HW_BYTES - 38;
    MAX_PSDU_BITS = MAX_PSDU_BYTES * 8;

    MAX_DATA_BYTES = MAX_PSDU_BYTES - length(header_mac)/8;
    MAX_DATA_BITS = MAX_DATA_BYTES * 8;

    if strcmpi(cfgNonHT.Preamble, 'Long')
        PLCP_time = 192e-6; % Clause 17.2.2.2 Long PPDU format
    else
        PLCP_time = 96e-6; % Clause 17.2.2.3 Short PPDU format
    end
    
    % No blank symbols in case signals can overlap
    if ~overlap
        blankSymbols = wlanSampleRate(cfgNonHT) * PLCP_time + length(header_mac) + blanksymbols;
    else
        blankSymbols = blanksymbols;
    end

    % Clause 17.2.4 PLCP/High Rate PHY data scrambler and descrambler
    cfgInfo = wlan.internal.dsssInfo(cfgNonHT);
    scr = comm.Scrambler(2,'1+z^-4+z^-7', cfgInfo.ScramblerInitialization, 'ResetInputPort',true);
    descr = comm.Descrambler(2, '1+z^-4+z^-7', cfgInfo.ScramblerInitialization);
    preamble = [cfgInfo.Sync; cfgInfo.SFD];

    aSlotTime = 20e-6; % [µs]
    aSIFSTime = 10e-6; % [µs]
    DIFS = aSIFSTime + 2* aSlotTime;

    aCWmin = 31;
    ifs = DIFS + aCWmin/2 * aSlotTime; % always use aCWmin/2 This function does not know which value has been selected by WLAN NIC. aCWmin/2 is the expected value.
    ifsSymbols = ceil(wlanSampleRate(cfgNonHT) * ifs);

    % set dimension of bit vector. Lenght must be whole bytes so it might
    % be extended to the nearest byte
    if mod(length(nbIQ), 8) ~= 0
        dim = length(nbIQ) + 8 - mod(length(nbIQ), 8);
    else
        dim = length(nbIQ);
    end

    wifi_packets = ceil(dim/MAX_DATA_BITS);
        
    IQ_pointer = 1; % points to the beginning of chunk

    if MAX_PSDU_BITS ~= Inf
        bits = ones(wifi_packets, MAX_PSDU_BITS) * -1; % WARUM NICHT AUFGERUNDET WIE DIM?
    else
        bits = ones(1, length(nbIQ)) * -1;
    end
    
    chunk_id = 1;

    while IQ_pointer <= length(nbIQ)
        % punching to compensate preambles, headers and inter-frame spaces.
        % removes the bits that would fall inside of a space or header
        if IQ_pointer > 1 % apply to every chunk except the first
            % remove the beginnning of chunk that would be inside PLCP
            if ~DISABLE_BLANKING
                IQ_pointer = IQ_pointer + blankSymbols;
            end
            % remove the beginnning of chunk that would be inside IFS
            if ~DISABLE_IFS
                IQ_pointer = IQ_pointer + ifsSymbols;
            end
            % break if pointer exceeds length of nbIQ
            if IQ_pointer > length(nbIQ)
                break;
            end
        end
        
        % 1 CCK Symbol = 8 Bit = 8 Chips, 1 Chip = 2 Sample
        % Chiprate = 11 MChip / sec
        chunk = nbIQ(IQ_pointer : IQ_pointer + min(MAX_DATA_BITS - 1, length(nbIQ) - IQ_pointer));
        IQ_pointer = IQ_pointer + length(chunk);
        % Extend length of nbIQ to be divisible by 8
        if length(chunk) < MAX_DATA_BITS && mod(length(chunk), 8) ~= 0
            chunk = [chunk; zeros(8 - mod(length(chunk), 8), 1)]; %#ok<AGROW> % column vector
        end
        assert(length(chunk) <= MAX_DATA_BITS, "Chunk is larger than MAX_DATA_BITS");
        assert(mod(length(chunk),8) == 0, "Chunk size is not whole bytes");

        % Rebuild Narrowband signal by using only valid CCK-Codewords
        if mode == "std"
            [emulatedSignal, ~] = rebuildNB(chunk); % len x 1
        elseif mode == "opt"
            [emulatedSignal, ~] = rebuildNB_opt(chunk); % len x 1
        elseif mode == "filter"
            [emulatedSignal, ~] = rebuildNB_filter(chunk); % len x 1
        elseif mode == "phase"
            [emulatedSignal, ~] = rebuildNB_phase(chunk); % len x 1
        elseif mode == "dist"
            [emulatedSignal, ~] = rebuildNB_dist(chunk); % len x 1
        elseif mode == "distsep"
            [emulatedSignal, ~] = rebuildNB_dist_sep(chunk); % len x 1
        elseif mode == "sumdist"
            [emulatedSignal, ~] = rebuildNB_sumdist(chunk); % len x 1
        elseif mode == "sumdistsep"
            [emulatedSignal, ~] = rebuildNB_sumdist_sep(chunk); % len x 1
        elseif mode == "L1"
            [emulatedSignal, ~] = rebuildNB_L1(chunk); % len x 1
        elseif mode == "L2"
            [emulatedSignal, ~] = rebuildNB_L2(chunk); % len x 1
        end

        % Calculate PLCP fields that depend on PSDU length, calculate refPhase
        cfgNonHT.PSDULength = (length(header_mac) + length(emulatedSignal))/8; % length(emulatedSignal)/8;
        cfgInfo = wlan.internal.dsssInfo(cfgNonHT); % update cfgInfo, the one from above is not correct anymore

        cfgInfo.ScramblerInitialization = int2bit(scrambler_init,7,true).';

        header_crc = wlan.internal.dsssCRCGenerate([cfgInfo.Signal; cfgInfo.Service; cfgInfo.Length]);
        header_plcp = [cfgInfo.Signal; cfgInfo.Service; cfgInfo.Length; header_crc]; % TODO add bitstream MAC header

        scrambledPLCP = scr([preamble; header_plcp; header_mac], 1);

        if (strcmpi(cfgNonHT.Preamble,'Long'))
            % Repeat preamble and header bits; 'P' is also the right
            % number of modulated symbols to skip when extracting the
            % data part
            P = length([preamble; header_plcp]);
        else
            % Repeat just preamble bits; for short preamble the header
            % is already DQPSK; 'P' must be amended to skip the
            % modulated header symbols
            P = length(preambleBits);
        end
        % Repeat appropriate bits
        scrambledPLCP_l = reshape(repmat(scrambledPLCP(1:P,1),1,2).',P*2,1);
        % Amend 'P' for short preamble
        if (strcmpi(cfgNonHT.Preamble,'Short'))
            P = P + length(headerBits)/2;
        end
        
        pskSymbols = wlan.internal.dsssPSKModulate(scrambledPLCP_l,'2Mbps');
        refPhase = angle(pskSymbols(end));
        
        % if there is a mac header present, calculate phi_ref accordingly
        % daten from dsssCCKModulate
        if length(scrambledPLCP) > P
            if (strcmpi(cfgNonHT.DataRate,'5.5Mbps'))
                % Clause 17.4.6.6.3 CCK 5.5 Mb/s modulation
                cckOrder = 4;
            else
                % Clause 17.4.6.6.4 CCK 11 Mb/s modulation
                cckOrder = 8;
            end
            
            % Establish cckSymbols, the number of CCK symbols in the PSDU
            cckSymbols = (length(scrambledPLCP(P+1:end,1))/cckOrder);
            
            % Reshape the data bits to put modulation symbols in rows
            d = reshape(scrambledPLCP(P+1:end,1),cckOrder,cckSymbols).';
            % Calculate phi1
            phi1 = zeros(cckSymbols,1);
            % Initialize phi1 with reference phase from final header symbol
            phi1(1) = refPhase;
            % Extra 180 degree (pi) rotation on odd-numbered symbols
            phi1(2:2:end) = pi;
            % DQPSK modulation of dibit (d0,d1)
            dqpsk_in = [d(:,1).'; d(:,2).'];
            phi1 = mod(cumsum(phi1) + angle(wlan.internal.dsssPSKModulate( ...
                dqpsk_in(:),'2Mbps')), 2*pi);
    
            refPhase = phi1(end);
        end

        % Despread the emulated Signal: For each selected Codeword get the phases
        PSDU_phases = cckDeSpread(emulatedSignal); % len/8 x 4

        % Demodulate the phases to get the scrambled bits
        scrambledPSDU = cckDeModulate(PSDU_phases, refPhase); % len x 8
        scrambledPSDU = reshape(scrambledPSDU.', [],1);

        % Descramble the scrambled PPDU to get the payload
        descrambledPPDU = descr([scrambledPLCP; scrambledPSDU]);
        descrambledPSDU = descrambledPPDU(end-length(scrambledPSDU)+1:end);

        bits(chunk_id, 1:length(header_mac)) = header_mac.';
        bits(chunk_id, length(header_mac)+1:length(header_mac)+length(descrambledPSDU)) = descrambledPSDU;

        chunk_id = chunk_id +1;
    end
end

function [emulatedSignal, selectedIdxs] = rebuildNB(nbIQ)
    % rebuildNB selects the best fitting CCK codeword that emulates the
    % narrow-band IQ
    %   in:     nbIQ                narrow-band I/Q-signal that should be emulated
    %   out:    emulatedSignal      the emulated signal rebuild from CCK
    %                               codewords
    %           selectedIdx         a list of indexes that were selected
    % codegen

    possibleCCKCodewords = generateCCKCodewords();

    emulatedSignal = zeros(length(nbIQ), 1);
    selectedIdxs = zeros(length(nbIQ)/8, 1);
    counter = 1;
    for i = 1:8:length(nbIQ)
        chunk = nbIQ(i:i+7, :);
        corrReal = real(possibleCCKCodewords).' * real(chunk); %xcorr2(real(possibleCCKCodewords), real(chunk));
        corrImag = imag(possibleCCKCodewords).' * imag(chunk); %xcorr2(imag(possibleCCKCodewords), imag(chunk));

        corr = corrReal + corrImag; %corrReal(8,:) + corrImag(8,:); % 1x256
        [~, idx] = max(corr);

        %dlmwrite('chunk.csv',chunk.','delimiter',',','-append');
        %dlmwrite('correlations.csv',corr.','delimiter',',','-append');

        bestCodeword = possibleCCKCodewords(:,idx);
        emulatedSignal(i:i+7,:) = bestCodeword;

        selectedIdxs(counter) = idx;
        counter = counter + 1;
    end
end

function [emulatedSignal, selectedIdxs] = rebuildNB_phase(nbIQ)
    % rebuildNB selects the best fitting CCK codeword that emulates the
    % narrow-band IQ
    %   in:     nbIQ                narrow-band I/Q-signal that should be emulated
    %   out:    emulatedSignal      the emulated signal rebuild from CCK
    %                               codewords
    %           selectedIdx         a list of indexes that were selected
    % codegen

    possibleCCKCodewords = generateCCKCodewords();

    possibleCCKCodewords_phi = angle(possibleCCKCodewords);

    emulatedSignal = zeros(length(nbIQ), 1);
    selectedIdxs = zeros(length(nbIQ)/8, 1);
    counter = 1;
    for i = 1:8:length(nbIQ)
        chunk = nbIQ(i:i+7, :);
        chunk_phi = angle(chunk);
        corr = possibleCCKCodewords_phi.'  * chunk_phi;

        %dlmwrite('chunk.csv',chunk.','delimiter',',','-append');
        %dlmwrite('correlations.csv',corr.','delimiter',',','-append');

        %corrReal = real(possibleCCKCodewords).' * real(chunk); %xcorr2(real(possibleCCKCodewords), real(chunk));
        %corrImag = imag(possibleCCKCodewords).' * imag(chunk); %xcorr2(imag(possibleCCKCodewords), imag(chunk));

        %corr = corrReal + corrImag; %corrReal(8,:) + corrImag(8,:); % 1x256
        [~, idx] = max(corr);

        bestCodeword = possibleCCKCodewords(:,idx);
        emulatedSignal(i:i+7,:) = bestCodeword;

        selectedIdxs(counter) = idx;
        counter = counter + 1;
    end
end

function [emulatedSignal, selectedIdxs] = rebuildNB_L2(nbIQ)
    % rebuildNB selects the best fitting CCK codeword that emulates the
    % narrow-band IQ
    %   in:     nbIQ                narrow-band I/Q-signal that should be emulated
    %   out:    emulatedSignal      the emulated signal rebuild from CCK
    %                               codewords
    %           selectedIdx         a list of indexes that were selected
    % codegen

    possibleCCKCodewords = generateCCKCodewords();

    emulatedSignal = zeros(length(nbIQ), 1);
    selectedIdxs = zeros(length(nbIQ)/8, 1);
    counter = 1;
    for i = 1:8:length(nbIQ)
        chunk = nbIQ(i:i+7, :);

        corr = vecnorm(possibleCCKCodewords - chunk, 2); %sum(abs(possibleCCKCodewords - chunk));

        [~, idx] = min(corr);

        bestCodeword = possibleCCKCodewords(:,idx);
        emulatedSignal(i:i+7,:) = bestCodeword;

        selectedIdxs(counter) = idx;
        counter = counter + 1;
    end
end

function [emulatedSignal, selectedIdxs] = rebuildNB_L1(nbIQ)
    % rebuildNB selects the best fitting CCK codeword that emulates the
    % narrow-band IQ
    %   in:     nbIQ                narrow-band I/Q-signal that should be emulated
    %   out:    emulatedSignal      the emulated signal rebuild from CCK
    %                               codewords
    %           selectedIdx         a list of indexes that were selected
    % codegen

    possibleCCKCodewords = generateCCKCodewords();

    emulatedSignal = zeros(length(nbIQ), 1);
    selectedIdxs = zeros(length(nbIQ)/8, 1);
    counter = 1;
    for i = 1:8:length(nbIQ)
        chunk = nbIQ(i:i+7, :);

        corr = vecnorm(possibleCCKCodewords - chunk, 1); %sum(abs(possibleCCKCodewords - chunk));

        [~, idx] = min(corr);

        bestCodeword = possibleCCKCodewords(:,idx);
        emulatedSignal(i:i+7,:) = bestCodeword;

        selectedIdxs(counter) = idx;
        counter = counter + 1;
    end
end

function [emulatedSignal, selectedIdxs] = rebuildNB_dist(nbIQ)
    % rebuildNB selects the best fitting CCK codeword that emulates the
    % narrow-band IQ
    %   in:     nbIQ                narrow-band I/Q-signal that should be emulated
    %   out:    emulatedSignal      the emulated signal rebuild from CCK
    %                               codewords
    %           selectedIdx         a list of indexes that were selected
    % codegen

    possibleCCKCodewords = generateCCKCodewords();

    emulatedSignal = zeros(length(nbIQ), 1);
    selectedIdxs = zeros(length(nbIQ)/8, 1);
    counter = 1;
    for i = 1:8:length(nbIQ)
        chunk = nbIQ(i:i+7, :);

        corr = sum(abs(possibleCCKCodewords - chunk));

        [~, idx] = min(corr);

        bestCodeword = possibleCCKCodewords(:,idx);
        emulatedSignal(i:i+7,:) = bestCodeword;

        selectedIdxs(counter) = idx;
        counter = counter + 1;
    end
end

function [emulatedSignal, selectedIdxs] = rebuildNB_sumdist(nbIQ)
    % rebuildNB selects the best fitting CCK codeword that emulates the
    % narrow-band IQ
    %   in:     nbIQ                narrow-band I/Q-signal that should be emulated
    %   out:    emulatedSignal      the emulated signal rebuild from CCK
    %                               codewords
    %           selectedIdx         a list of indexes that were selected
    % codegen

    possibleCCKCodewords = generateCCKCodewords();

    emulatedSignal = zeros(length(nbIQ), 1);
    selectedIdxs = zeros(length(nbIQ)/8, 1);
    counter = 1;
    for i = 1:8:length(nbIQ)
        chunk = nbIQ(i:i+7, :);

        corr = abs(sum(possibleCCKCodewords - chunk));

        [~, idx] = min(corr);

        bestCodeword = possibleCCKCodewords(:,idx);
        emulatedSignal(i:i+7,:) = bestCodeword;

        selectedIdxs(counter) = idx;
        counter = counter + 1;
    end
end


function [emulatedSignal, selectedIdxs] = rebuildNB_dist_sep(nbIQ)
    % rebuildNB selects the best fitting CCK codeword that emulates the
    % narrow-band IQ
    %   in:     nbIQ                narrow-band I/Q-signal that should be emulated
    %   out:    emulatedSignal      the emulated signal rebuild from CCK
    %                               codewords
    %           selectedIdx         a list of indexes that were selected
    % codegen

    possibleCCKCodewords = generateCCKCodewords();

    emulatedSignal = zeros(length(nbIQ), 1);
    selectedIdxs = zeros(length(nbIQ)/8, 1);
    counter = 1;
    for i = 1:8:length(nbIQ)
        chunk = nbIQ(i:i+7, :);

        rep = abs(real(possibleCCKCodewords) - real(chunk));
        imp = abs(imag(possibleCCKCodewords) - imag(chunk));

        corr = sum(rep) + sum(imp);
        
        [~, idx] = min(corr);

        bestCodeword = possibleCCKCodewords(:,idx);
        emulatedSignal(i:i+7,:) = bestCodeword;

        selectedIdxs(counter) = idx;
        counter = counter + 1;
    end
end

function [emulatedSignal, selectedIdxs] = rebuildNB_sumdist_sep(nbIQ)
    % rebuildNB selects the best fitting CCK codeword that emulates the
    % narrow-band IQ
    %   in:     nbIQ                narrow-band I/Q-signal that should be emulated
    %   out:    emulatedSignal      the emulated signal rebuild from CCK
    %                               codewords
    %           selectedIdx         a list of indexes that were selected
    % codegen

    possibleCCKCodewords = generateCCKCodewords();

    emulatedSignal = zeros(length(nbIQ), 1);
    selectedIdxs = zeros(length(nbIQ)/8, 1);
    counter = 1;
    for i = 1:8:length(nbIQ)
        chunk = nbIQ(i:i+7, :);

        rep = (real(possibleCCKCodewords) - real(chunk));
        imp = (imag(possibleCCKCodewords) - imag(chunk));

        corr = abs(sum(rep) + sum(imp));
        
        [~, idx] = min(corr);

        bestCodeword = possibleCCKCodewords(:,idx);
        emulatedSignal(i:i+7,:) = bestCodeword;

        selectedIdxs(counter) = idx;
        counter = counter + 1;
    end
end

function [emulatedSignal, selectedIdxs] = rebuildNB_opt(nbIQ)
    % rebuildNB selects the best fitting CCK codeword that emulates the
    % narrow-band IQ
    %   in:     nbIQ                narrow-band I/Q-signal that should be emulated
    %   out:    emulatedSignal      the emulated signal rebuild from CCK
    %                               codewords
    %           selectedIdx         a list of indexes that were selected
    % codegen

    %possibleCCKCodewords = generateCCKCodewords();

    emulatedSignal = zeros(length(nbIQ), 1);
    selectedIdxs = zeros(length(nbIQ)/8, 1);
    counter = 1;
    for i = 1:8:length(nbIQ)
        chunk = nbIQ(i:i+7, :);
        
        phi = cck_despread_optim(chunk);

        bestCodeword = wlan.internal.dsssCCKSpread(phi);
        emulatedSignal(i:i+7,:) = bestCodeword;

        %selectedIdxs(counter) = idx;
        counter = counter + 1;
    end
end

function est_phases = cck_despread_optim(received_symbol)
    % received_symbol: 8x1 complex vector
    % est_phases: estimated [phi1, phi2, phi3, phi4]

    % Extract received phases
    received_phases = angle(received_symbol);

    % Optimization options
    options = optimoptions('fminunc', ...
        'Algorithm', 'quasi-newton', ...
        'Display', 'off');

    % Initial guess
    phi0 = [0, 0, 0, 0];  % Initial guess for [phi1, phi2, phi3, phi4]

    % Define loss function: squared angular error
    loss_fn = @(phi) phase_loss(phi, received_phases);

    % Solve optimization problem
    est_phases = fminunc(loss_fn, phi0, options);

    % Wrap to [0, 2pi)
    est_phases = mod(est_phases, 2*pi);
end

function err = phase_loss(phi, received_phases)

    spread = [ 1  1  1  1;
             1  0  1  1;
             1  1  0  1;
             1  0  0  1;
             1  1  1  0;
             1  0  1  0;
             1  1  0  0;
             1  0  0  0; ];

    model_phases = spread * phi.';

    % Wrap model phases to [-pi, pi]
    model_phases = mod(model_phases + pi, 2*pi) - pi;

    % Compute phase error (modulo 2pi difference)
    diff = received_phases - model_phases;
    wrapped_diff = angle(exp(1j * diff));
    err = sum(wrapped_diff.^2);
end

function [emulatedSignal, selectedIdxs] = rebuildNB_filter(nbIQ)
    % rebuildNB selects the best fitting CCK codeword that emulates the
    % narrow-band IQ
    %   in:     nbIQ                narrow-band I/Q-signal that should be emulated
    %   out:    emulatedSignal      the emulated signal rebuild from CCK
    %                               codewords
    %           selectedIdx         a list of indexes that were selected
    % codegen

    hist_len = 3 * 8;

    possibleCCKCodewords = generateCCKCodewords();

    emulatedSignal = zeros(length(nbIQ), 1);
    selectedIdxs = zeros(length(nbIQ)/8, 1);
    counter = 1;
    for i = 1:8:length(nbIQ)
        start_i = max(1, i - hist_len);
        chunk = nbIQ(start_i:i+7, :);
        presection = emulatedSignal(start_i:(i-1));

        extended_codes_t = [repmat(presection, 1, 256); possibleCCKCodewords];

        extended_codes = lowpass(extended_codes_t, 812e3,11e6);

        corrReal = real(extended_codes).' * real(chunk); %xcorr2(real(possibleCCKCodewords), real(chunk));
        corrImag = imag(extended_codes).' * imag(chunk); %xcorr2(imag(possibleCCKCodewords), imag(chunk));

        corr = corrReal + corrImag; %corrReal(8,:) + corrImag(8,:); % 1x256
        [~, idx] = max(corr);

        bestCodeword = possibleCCKCodewords(:,idx);
        emulatedSignal(i:i+7,:) = bestCodeword;

        selectedIdxs(counter) = idx;
        counter = counter + 1;
    end
end

function codewords = generateCCKCodewords()
    % generateCCCodewords generates all possible combinations of
    % CCK-codewords
    %   out:    codewords   list of all possible codewords
    phases = [0 pi/2 pi 3/2*pi];
    phaseCombinations = permn(phases, 4); % 256x4
    possibleCCKCodewords = wlan.internal.dsssCCKSpread(phaseCombinations); % 2048x1

    codewords = reshape(possibleCCKCodewords, 8, []);
end

function phi = cckDeSpread(codewords)
    % cckDeSpread reverses the spreading as defined in IEEE 802.11

    % convert len x 1 to 8 x len/8
    codewords = reshape(codewords, 8, []);

    phi = zeros(size(codewords,2), 4);
    for i=1:size(codewords,2) % use size instead of length. Else it may evaluate the wrong dimension
        phi(i, 1) = angle(codewords(8,i));
        phi(i, 2) = angle((-1)*codewords(7,i)) - phi(i,1);
        phi(i, 3) = angle(codewords(6,i)) - phi(i,1);
        phi(i, 4) = angle((-1)*codewords(4,i)) - phi(i,1);
        phi(i, :) = mod(phi(i,:), 2*pi);
    end
end

function scrambledPSDU = cckDeModulate(phi, phi_ref)

   % Clause 17.4.6.6.4 CCK 11 Mb/s modulation

   cckSymbols = size(phi,1);
   scrambledPSDU = zeros(cckSymbols,8);
   
   phi1_diff = zeros(1,cckSymbols);
   phi1_diff(1) = phi_ref;
   phi1_diff(2:2:end) = pi;
   phi1_diff = mod(cumsum(phi1_diff), 2*pi);
   
   phi1 = mod(phi(:,1).' - phi1_diff, 2*pi);
   demod_phi1 = dpskdemod(exp(1i*phi1),4,0,'gray');

   scrambledPSDU(:,1:2) = de2bi(demod_phi1,2,'left-msb');
   
   scrambledPSDU(:,3:8) = pskdemod(exp(1i*(phi(:,2:4))).',4, 0, 'bin', 'OutputType', 'bit').';

end