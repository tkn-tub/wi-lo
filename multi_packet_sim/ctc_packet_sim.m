% test.m

function psdu_wave = ctc_packet_sim(waveform, jitter, known_delay, ...
        unknown_delay, wifi_mac, shift, MAX_HW_BYTES, mode, preamble_short, ...
        overlap)
    addpath("../perm/");
    addpath("../");

    used_mac_header = [];
    delay = known_delay + unknown_delay;

    scrambler_init = 108;   % value according to the standard. Is different for Realtek cards
    DISABLE_IFS = true;
    DISABLE_PLCP = false;

    if wifi_mac
        used_mac_header = get_wifi_bits();
    end
    
    waveform_shift = [zeros(shift,1); waveform];

    preamble_type = "Long";

    if preamble_short
        preamble_type = "Short";
    end
                
    % Wi-Lo
    cfgNonHT = wlanNonHTConfig('Modulation', 'DSSS', 'DataRate', '11Mbps', 'Preamble', preamble_type, 'LockedClocks', true);
    bits = WiFi_bits(waveform_shift, used_mac_header, cfgNonHT, scrambler_init, ...
        DISABLE_IFS, DISABLE_PLCP, jitter*2 + known_delay, MAX_HW_BYTES, mode, overlap); % generate bits that emulate the lora waveform
    assert(mod(length(bits),8)==0, "LoRa_Emulate_80211b did not return whole bytes");
    
    % send Wi-Lo frame
    cfgNonHT = wlanNonHTConfig('Modulation', 'DSSS', 'DataRate', '11Mbps', 'Preamble', preamble_type, 'LockedClocks', true);
    % cfgInfo = wlan.internal.dsssInfo(cfgNonHT);
    % scrambInit = bit2int(cfgInfo.ScramblerInitialization', 7);

    if strcmpi(cfgNonHT.Preamble, 'Long')
        PLCP_time = 192e-6; % Clause 17.2.2.2 Long PPDU format
    else
        PLCP_time = 96e-6; % Clause 17.2.2.3 Short PPDU format
    end

    len_header = length(used_mac_header) + wlanSampleRate(cfgNonHT) * PLCP_time;
    
    psdu_wave = [];

    if overlap
        psdu_wave = zeros(length(waveform_shift)+10000+size(bits,1)*(delay+4*jitter)+len_header,1);
    end

    ptr = 1;

    for i=1:size(bits,1)
        mybits = bits(i,:);

        myend = find(mybits==-1,1,'first');

        if isempty(myend)
            myend = size(bits,2);
        else
            myend = myend -1;
        end

        if myend < 1
            break;
        end

        myjitter = - 3*jitter;

        while abs(myjitter) > 2*jitter
            myjitter = normrnd(0, jitter);
        end

        myjitter = myjitter + 2 * jitter;
    
        cfgNonHT.PSDULength = min(length(mybits(1:myend)) / 8, 2266);

        if overlap
            twave = wlanWaveformGenerator(mybits(1:myend), cfgNonHT);
            psdu_wave(ptr:(ptr+length(twave)-1)) = psdu_wave(ptr:(ptr+length(twave)-1)) + twave;
            ptr = ptr + length(twave) - len_header;
            ptr = ptr + delay + myjitter;

        else
            if ~isempty(psdu_wave)
                psdu_wave = [psdu_wave; zeros(delay,1); zeros(round(myjitter), 1); wlanWaveformGenerator(mybits(1:myend), cfgNonHT)];
            else
                psdu_wave = wlanWaveformGenerator(mybits(1:myend), cfgNonHT);
            end
        end
    end

    myjitter = - 3*jitter;

    while abs(myjitter) > 2*jitter
        myjitter = normrnd(0, jitter);
    end

    myjitter = myjitter + 2 * jitter;

    if ~overlap
        psdu_wave = [psdu_wave; zeros(delay,1); zeros(round(myjitter), 1); wlanWaveformGenerator(0, cfgNonHT)];
    end
end



function wifi_mac_header=get_wifi_bits()
    mac_header_len = 36;
    beaconCfg = wlanMACFrameConfig(FrameType='Beacon');
    beaconCfg.FromDS = 0;
    
    % disp(beaconCfg);
    
    % Create a management frame-body configuration object
    frameBodyCfg = wlanMACManagementConfig;
    frameBodyCfg.BasicRates = {'1 Mbps', '11 Mbps'};
    
    % disp(frameBodyCfg);
    
    % Beacon Interval
    frameBodyCfg.BeaconInterval = 100;
    % Timestamp
    frameBodyCfg.Timestamp = 123456;
    % SSID
    frameBodyCfg.SSID = 'TEST_BEACON';
    % Add DS Parameter IE (element ID - 3) with channel number 11 (0x0b)
    frameBodyCfg = frameBodyCfg.addIE(3, '01');
    
    % Update management frame-body configuration
    beaconCfg.ManagementConfig = frameBodyCfg;
    
    % Generate octets for a Beacon frame
    % beaconFrame = wlanMACFrame(beaconCfg);
    
    % Generate bits for a Beacon frame
    beaconFrameBits = wlanMACFrame(beaconCfg, OutputFormat='bits');
    
    wifi_mac_header = beaconFrameBits(1:mac_header_len * 8);
end
