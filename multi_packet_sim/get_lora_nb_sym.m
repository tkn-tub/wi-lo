function [lora_nb, symbols]=get_lora_nb_sym(sf, fs_wifi, payload, cr, bw, rf_freq)
    %rf_freq = 2412e6;    % carrier frequency 470 MHz, used to correct clock drift
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
