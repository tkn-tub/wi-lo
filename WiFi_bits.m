function bits = WiFi_bits(nbIQ, header_mac, cfgNonHT, scrambler_init, DISABLE_IFS, DISABLE_BLANKING)
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
    MAX_PSDU_BYTES = 2304 - 38;
    MAX_PSDU_BITS = MAX_PSDU_BYTES * 8;

    MAX_DATA_BYTES = MAX_PSDU_BYTES - length(header_mac)/8;
    MAX_DATA_BITS = MAX_DATA_BYTES * 8;

    if strcmpi(cfgNonHT.Preamble, 'Long')
        PLCP_time = 192e-6; % Clause 17.2.2.2 Long PPDU format
    else
        PLCP_time = 96e-6; % Clause 17.2.2.3 Short PPDU format
    end
    blankSymbols = wlanSampleRate(cfgNonHT) * PLCP_time;

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
    bits = ones(wifi_packets, MAX_PSDU_BITS) * -1; % WARUM NICHT AUFGERUNDET WIE DIM?
    
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
        [emulatedSignal, ~] = rebuildNB(chunk); % len x 1

        % Calculate PLCP fields that depend on PSDU length, calculate refPhase
        cfgNonHT.PSDULength = (length(header_mac) + length(emulatedSignal))/8; % length(emulatedSignal)/8;
        cfgInfo = wlan.internal.dsssInfo(cfgNonHT); % update cfgInfo, the one from above is not correct anymore

        cfgInfo.ScramblerInitialization = int2bit(scrambler_init,7,true).';

        header_crc = wlan.internal.dsssCRCGenerate([cfgInfo.Signal; cfgInfo.Service; cfgInfo.Length]);
        header_plcp = [cfgInfo.Signal; cfgInfo.Service; cfgInfo.Length; header_crc]; % TODO add bitstream MAC header

        scrambledPLCP = scr([preamble; header_plcp; header_mac], 1);
        pskSymbols = wlan.internal.dsssPSKModulate(scrambledPLCP,'2Mbps');
        refPhase = angle(pskSymbols(end));


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
        corrReal = xcorr2(real(possibleCCKCodewords), real(chunk));
        corrImag = xcorr2(imag(possibleCCKCodewords), imag(chunk));

        corr = corrReal(8,:) + corrImag(8,:); % 1x256
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
