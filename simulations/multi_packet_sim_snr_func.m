function multi_packet_sim_snr_func(bws, wifi_mac, preamble_short, overlap, purlora, payload_length, snrs)
    
    addpath("../perm/");
    addpath("../");
    addpath("../multi_packet_sim");
    
    datapath = "data/snr_100/";
    
    %payload_length = 10;
    sfs = [5:12];
    crs = 1;%[1, 4];
    %bws = [203e3, 1625e3];
    runs = 1000; %000;
    %snrs = [-40:1:15];
    %purlora = false;
    
    knowndelays = [0];
    unknowndelays = [0];
    jitters = [0];
    
    %wifi_mac = true;
    %preamble_short = false;
    %overlap = false;
    
    multi_packet_sim(sfs, bws, crs, runs, payload_length, ...
        knowndelays, unknowndelays, jitters, snrs, datapath, purlora, ...
        wifi_mac, preamble_short, overlap);
end
