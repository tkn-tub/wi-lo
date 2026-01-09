function wifi_payload = wilo_func(settings, payload)
    
    wifi_payload = {};

    disp(class(payload));
    
    rf_freq = settings.lora.frequency;    % carrier frequency 470 MHz, used to correct clock drift
    sf = settings.lora.sf;             % spreading factor SF7
    bw = settings.lora.bw;         % bandwidth 125 kHz
    fs_lora = 6.5e6;           % sampling rate 1 MHz
    fs_wifi = 11e6;
    wifi_mac = true;

    mac_header_len = 36;
    scrambler_init = settings.scrambler_init;   % value according to the standard. Is different for Realtek cards
    
    disp([rf_freq, sf, bw]);
    
    phy = LoRaPHY(rf_freq, sf, bw, fs_lora);
    phy.has_header = 1;         % explicit header mode
    phy.cr = settings.lora.cr;  % code rate = 4/8 (1:4/5 2:4/6 3:4/7 4:4/8)
    phy.crc = 1;                % enable payload CRC checksum
    phy.preamble_len = 8;       % preamble: 8 basic upchirps
    phy.netid = [9 16];
    
    % Encode payload [1 2 3 4 5]
    symbols = phy.encode(uint8(convertStringsToChars(payload).'));
    fprintf("[encode] symbols:\n");
    disp(symbols);
    
    % Baseband Modulation
    sig = phy.modulate(symbols);
    
    sig_norm = conj(sig);
    lorawaveform_11 = resample(sig_norm, fs_wifi, fs_lora);
    length_lora = ceil(length(lorawaveform_11) / 8);
    
    %% Beacon generation to get 802.11 mac header bits
    
    beaconCfg = wlanMACFrameConfig(FrameType='Beacon');
    beaconCfg.FromDS = 0;
    
    disp(beaconCfg);
    
    % Create a management frame-body configuration object
    frameBodyCfg = wlanMACManagementConfig;
    frameBodyCfg.BasicRates = {'1 Mbps', '11 Mbps'};
    
    disp(frameBodyCfg);
    
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
    beaconFrame = wlanMACFrame(beaconCfg);
    
    % Generate bits for a Beacon frame
    beaconFrameBits = wlanMACFrame(beaconCfg, OutputFormat='bits');
    
    wifi_mac_bits = beaconFrameBits(1:mac_header_len * 8);
    
    used_mac_header = [];
    
    if wifi_mac
        used_mac_header = wifi_mac_bits;
    end
    
    
    %% WiLo preparation
    
    addpath("perm/")
    
    DISABLE_IFS = true;
    DISABLE_PLCP = false;
    
    aCWmin = 31;
    aCWmax = 1023;
    aSlotTime = 20e-6; % [us]
    aSIFSTime = 10e-6; % [us]
    DIFS = aSIFSTime + 2* aSlotTime;
    ifs = 0;
    
    %% Generate bits
    
    cfgNonHT = wlanNonHTConfig('Modulation', 'DSSS', 'DataRate', '11Mbps', 'Preamble', 'Long', 'LockedClocks', true);
    bits = WiFi_bits(lorawaveform_11, used_mac_header, cfgNonHT, scrambler_init, DISABLE_IFS, DISABLE_PLCP); % generate bits that emulate the lora waveform
    assert(mod(length(bits),8)==0, "LoRa_Emulate_80211b did not return whole bytes");
    
    disp("Done with generating bits.")
    
    %% Convert bits to bytes
    
    for i=1:size(bits,1)
        
        mybits = bits(i,:);
        myend = find(mybits==-1,1,'first');
    
        if isempty(myend)
            myend = size(bits,2);
        else
            myend = myend -1;
        end
    
        bytes = bit2int(mybits(1:myend).',8,false);

        wifi_payload{end+1} = bytes;
    end
    
    disp("Done with writing bytes to file.")
end