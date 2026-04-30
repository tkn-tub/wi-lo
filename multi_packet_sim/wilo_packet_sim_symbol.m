% test.m

function [psdu_wave,symbol] = wilo_packet_sim_symbol(sf, cr, bw, payload, jitter, known_delay, ...
        unknown_delay, wifi_mac, shift, MAX_HW_BYTES, mode, preamble_short, overlap)
    addpath("../perm/");
    addpath("../");


    fs_wifi = 11e6;
    rf_wifi = 2412e6;

    [lorawaveform_11,symbol]= get_lora_nb_sym(sf, fs_wifi, payload, cr, bw, rf_wifi);

    psdu_wave=ctc_packet_sim(lorawaveform_11, jitter, known_delay, ...
        unknown_delay, wifi_mac, shift, MAX_HW_BYTES, mode, ...
        preamble_short, overlap);

end


    
  
