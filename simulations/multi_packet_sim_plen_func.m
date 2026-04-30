function multi_packet_sim_plen_func(bws, wifi_mac, preamble_short, overlap, purlora)
    
    addpath("../perm/");
    addpath("../");
    addpath("../multi_packet_sim");
    
    datapath = "data/plen/";
    
    payload_lengths = [1 [1:40]*5];
    sfs = [5:12];
    crs = [1, 4];
    %bws = [203e3, 1625e3];
    runs = 100;
    snrs = Inf;
    %purlora = false;
    
    knowndelays = [0];
    unknowndelays = [0];
    jitters = [0];
    
    %wifi_mac = true;
    %preamble_short = false;
    %overlap = false;
    
    multi_packet_sim(sfs, bws, crs, runs, payload_lengths, ...
        knowndelays, unknowndelays, jitters, snrs, datapath, purlora, ...
        wifi_mac, preamble_short, overlap);
end
