function payload=decode_lora_nb(sf, fs_wifi, lora_nb, cr, bw, rf_freq)
    % rf_freq = 2412e6;    % carrier frequency 470 MHz, used to correct clock drift
    fs_lora = bw*2;           % sampling rate 1 MHz
    
    
    phy = LoRaPHY(rf_freq, sf, bw, fs_lora);
    phy.has_header = 1;         % explicit header mode
    phy.cr = cr;                 % code rate = 4/8 (1:4/5 2:4/6 3:4/7 4:4/8)
    phy.crc = 1;                % enable payload CRC checksum
    phy.preamble_len = 8;       % preamble: 8 basic upchirps
    phy.netid = [9 16];

    sig_norm = resample(lowpass(lora_nb, bw/2, fs_wifi), fs_lora, fs_wifi);
    sig = conj(sig_norm);

    symbols = phy.demodulate(sig);
    % disp(symbols);
    payload = phy.decode(symbols).';

    clearvars phy;
end
