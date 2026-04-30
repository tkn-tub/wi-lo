% test.m

function psdu_wave = wilo_packet_sim(sf, cr, bw, payload, jitter, known_delay, ...
        unknown_delay, wifi_mac, shift, MAX_HW_BYTES, mode, preamble_short, ...
        overlap)
    addpath("../perm/");
    addpath("../");


    fs_wifi = 11e6;

    lorawaveform_11= get_lora_nb(sf, fs_wifi, payload, cr, bw);

    psdu_wave=ctc_packet_sim(lorawaveform_11, jitter, known_delay, ...
        unknown_delay, wifi_mac, shift, MAX_HW_BYTES, mode, preamble_short, ...
        overlap);

end



function lora_nb=get_lora_nb(sf, fs_wifi, payload, cr, bw)
    rf_freq = 2412e6;    % carrier frequency 470 MHz, used to correct clock drift
    %bw = 1625e3;         % bandwidth 125 kHz
    fs_lora = bw * 4;           % sampling rate 1 MHz
    
    
    phy = LoRaPHY(rf_freq, sf, bw, fs_lora);
    phy.has_header = 1;         % explicit header mode
    phy.cr = cr;                 % code rate = 4/8 (1:4/5 2:4/6 3:4/7 4:4/8)
    phy.crc = 1;                % enable payload CRC checksum
    phy.preamble_len = 8;       % preamble: 8 basic upchirps
    phy.netid = [9 16];
    
    % Encode payload [1 2 3 4 5]
    symbols = phy.encode(payload.');
    fprintf("[encode] symbols:\n");
    % disp(symbols);
    
    % Baseband Modulation
    sig = phy.modulate(symbols);
    
    sig_norm = conj(sig);
    %lora_nb = sig_norm;
    lora_nb = resample(sig_norm, fs_wifi, fs_lora);

    clearvars phy;
end