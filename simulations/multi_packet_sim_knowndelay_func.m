function multi_packet_sim_knowndelay_func(bws, wifi_mac, preamble_short, overlap, purlora)

    addpath("../perm/");
    addpath("../");
    addpath("../multi_packet_sim");
    
    datapath = "data/known_delay/";
    
    payload_length = 10;
    sfs = [5:12];
    crs = [1, 4];
    %bws = [203e3, 1625e3];
    runs = 100;
    snrs = [Inf];
    %purlora = false;
    
    knowndelays = [0, 1, 11, 110, 330, 550, 1.1e3, 1.1e4, 1.1e5];
    unknowndelays = [0];
    jitters = [0];
    
    multi_packet_sim(sfs, bws, crs, runs, payload_length, ...
        knowndelays, unknowndelays, ...
        jitters, snrs, datapath, purlora, ...
        wifi_mac, preamble_short, overlap);
end
