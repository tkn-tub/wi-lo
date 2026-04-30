function multi_packet_sim(sfs, bws, crs, runs, payload_lengths, ...
    knowndelays, unknowndelays, jitters, snrs, datapath, purlora, ...
    wifi_mac, preamble_short, overlap)
    % TODO
    fs_wifi = 11e6;
    rf_freq = 2.412e9;
    show_spectrogram = true;
    WiLo_packet_size = 2304;

    
    addpath("../perm/");
    addpath("../");
    
    plotting = false;

    fh = @sim_intern;
    memoizedSim = memoize(fh);

    memoizedSim=fh; %TODO

    %payload_orig = [1:payload_length];

    for jitter_i = 1:length(jitters)
        jitter = jitters(jitter_i);
        
        for knowndelay_i = 1:length(knowndelays)
            known_delay = knowndelays(knowndelay_i);
            
            for unknowndelays_i = 1:length(unknowndelays)
                unknown_delay = unknowndelays(unknowndelays_i);

                preamble_detect = zeros(length(sfs), length(crs), runs) -1;
                payload_error = zeros(length(sfs), length(crs), runs) -1;

                for payload_i = 1:length(payload_lengths)
                    payload_length = payload_lengths(payload_i);

                    for snr_i=1:length(snrs)
                        snr = snrs(snr_i);
                    
                        for bw_i=1:length(bws)
                            bw = bws(bw_i);
                        
                            experimentstring = strcat("_plen", int2str(payload_length), ...
                                            "_bw", int2str(bw), ...
                                            "_jitter", int2str(jitter), ...
                                            "_delayknown", int2str(known_delay), ...
                                            "_delayunknown", int2str(unknown_delay), ...
                                            "_snr", int2str(snr), ...
                                            "_purlora", int2str(purlora), ...
                                            "_wifimac", int2str(wifi_mac), ...
                                            "_shortpreamble", int2str(preamble_short), ...
                                            "_overlap", int2str(overlap));
            
                            for cr_i=1:length(crs)
                                cr = crs(cr_i);
                                
                                if show_spectrogram && plotting
                                    fig = figure;
                                    sgtitle(strcat("CR=4/", int2str(4+cr)));
                                end
    
                                payload_orig = randi([0,255],payload_length,1).';
    
                                [psdu_wave, symbols_test]= get_lora_nb_sym(min(sfs), fs_wifi, payload_orig, cr, bw, rf_freq);
    
                                errormap = zeros(length(sfs), payload_length, runs) -1;
                                errormap_sym = zeros(length(sfs), length(symbols_test), runs) -1;
                                
                                for run_i = 1:runs %TODO parfor
    
                                    payload_orig = randi([0,255],payload_length,1).';
    
                                    [psdu_wave, symbols_test]= get_lora_nb_sym(min(sfs), fs_wifi, payload_orig, cr, bw, rf_freq);
    
                                    [preamble_detect_run, errormap_run, errormap_sym_run, payload_error_run] = memoizedSim( ...
        sfs, bw, cr, snr, fs_wifi, rf_freq, payload_length, payload_orig, symbols_test, ...
        jitter, known_delay, unknown_delay, wifi_mac, WiLo_packet_size, preamble_short, purlora,...
        show_spectrogram, plotting, overlap);
    
                                    
    
                                    preamble_detect(:, cr_i, run_i) = preamble_detect_run;
                                    errormap(:,:, run_i) = errormap_run;
                                    errormap_sym(:,:, run_i) = errormap_sym_run;
                                    payload_error(:, cr_i, run_i) = payload_error_run;
                                    
                                    if show_spectrogram && plotting
                                        saveas(fig, strcat(datapath, ...
                                            "wilo_spectrum_cr", int2str(cr), ...
                                            "_run", int2str(run_i), ...
                                            experimentstring, ".pdf"));
                                        saveas(fig, strcat(datapath, ...
                                            "wilo_spectrum_cr", int2str(cr), ...
                                            "_run", int2str(run_i), ...
                                            experimentstring, ".fig"));
                                    end
                                    
                                    if  plotting
                                        clrmap = [1 1 1
                                            1 0 0];
                                        
                                        fig = figure;
                                        heatmap(1:payload_length,sfs,errormap(:,:, run_i), "Colormap",clrmap);
                                        xlabel("symbol position");
                                        ylabel("sf");
                                        sgtitle(strcat("error map CR=4/", int2str(4+cr)));
                                    
                                        saveas(fig, strcat(datapath, ...
                                            "wilo_errormap_cr", int2str(cr), ...
                                            "_run", int2str(run_i), ...
                                            experimentstring, ".pdf"));
                                        saveas(fig, strcat(datapath, ...
                                            "wilo_errormap_cr", int2str(cr), ...
                                            "_run", int2str(run_i), ...
                                            experimentstring, ".fig"));
                                        close all;
                                    end
                                end % runs
                        
                                save(strcat(datapath, "wilo_errormap_cr", int2str(cr), ...
                                    experimentstring, ".mat"), "errormap","errormap_sym", ...
                                    "cr", "sfs", "bw", "crs", "runs", ...
                                    "payload_length", "jitter", "known_delay", ...
                                    "unknown_delay", "snr");
                            end %end cr
                            
                            if plotting
                                fig = figure;
                                bar(sfs, payload_error, 'BaseValue',-0.04);
                                ylim([-0.04 max(payload_error, [], "all") + 0.05]);
                                legend('CR = 4/5','CR = 4/6','CR = 4/7','CR = 4/8')
                                xlabel("sf");
                                ylabel("payload error rate");
                                
                                saveas(fig, strcat(datapath, "wilo", ...
                                    experimentstring, ".pdf"));
                                saveas(fig, strcat(datapath, "wilo", ...
                                    experimentstring,  ".fig"));
                            end
                                
                            save(strcat(datapath, "wilo_payloaderror", ...
                                experimentstring, ".mat"), ...
                                "payload_error", "sfs", "bw", "crs", "runs", ...
                                "payload_length", "jitter", "known_delay", ...
                                "unknown_delay", "snr", "preamble_detect", ...
                                "wifi_mac", "preamble_short", "overlap");
    
                        end % end bws
                    end % end snr
                end %end payloadlength
            end %end unknown delay
        end %end known delay
    end %end jitter
end %function

function bestshift=get_bestshift(sf,cr,bw,short, mac, overlap)
    % normal WiFi card
    if ~short && mac && ~overlap
        if bw==203e3
            if cr==1
                bestshifts = [4100; 1600; 0; 0; 0; 0; 0; 0];
            elseif cr==4
                bestshifts = [8700; 2200; 0; 0; 0; 0; 0; 0];
            else
                error("cr not valid");
            end
            
        elseif bw == 1625e3
            if cr==1
                bestshifts = [0; 0; 2400; 7400; 14900; 0; 0; 0];
            elseif cr==4
                bestshifts = [0; 14000; 8000; 3100; 500; 0; 0; 0];
            else
                error("cr not valid");
            end
        else
            error("bw not valid");
        end
    % short preamble
    elseif short && mac && ~overlap
        if bw==203e3
            if cr==1
                bestshifts = [1000; 0; 400; 0; 0; 0; 0; 0];
            elseif cr==4
                bestshifts = [0; 0; 0; 0; 0; 0; 0; 0];
            else
                error("cr not valid");
            end
            
        elseif bw == 1625e3
            if cr==1
                bestshifts = [0; 12300; 3200; 4500; 9100; 0; 0; 0];
            elseif cr==4
                bestshifts = [15900; 2100; 7600; 0; 0; 0; 0; 0];
            else
                error("cr not valid");
            end
        else
            error("bw not valid");
        end
    % long preamble and no mac
    elseif ~short && ~mac && ~overlap
        if bw==203e3
            if cr==1
                bestshifts = [3800; 1500; 0; 0; 0; 0; 0; 0];
            elseif cr==4
                bestshifts = [100; 100; 0; 0; 0; 0; 0; 0];
            else
                error("cr not valid");
            end
            
        elseif bw == 1625e3
            if cr==1
                bestshifts = [0; 0; 2400; 7500; 2300; 0; 0; 0];
            elseif cr==4
                bestshifts = [0; 14300; 8100; 100; 0; 0; 0; 0];
            else
                error("cr not valid");
            end
        else
            error("bw not valid");
        end
    % short preamble and no mac
    elseif short && ~mac && ~overlap
        if bw==203e3
            if cr==1
                bestshifts = [1600; 0; 0; 0; 0; 0; 0; 0];
            elseif cr==4
                bestshifts = [0; 0; 0; 0; 0; 0; 0; 0];
            else
                error("cr not valid");
            end
            
        elseif bw == 1625e3
            if cr==1
                bestshifts = [0; 9500; 3400; 4800; 0; 0; 0; 0];
            elseif cr==4
                bestshifts = [15800; 2100; 7300; 0; 0; 0; 0; 0];
            else
                error("cr not valid");
            end
        else
            error("bw not valid");
        end
    % nomal with overlap
    elseif ~short && mac && overlap
        if bw==203e3
            if cr==1
                bestshifts = [0; 0; 0; 0; 0; 0; 0; 0];
            elseif cr==4
                bestshifts = [0; 0; 0; 0; 0; 0; 0; 0];
            else
                error("cr not valid");
            end
            
        elseif bw == 1625e3
            if cr==1
                bestshifts = [0; 0; 200; 800; 200; 0; 0; 0];
            elseif cr==4
                bestshifts = [0; 0; 0; 0; 0; 0; 0; 0];
            else
                error("cr not valid");
            end
        else
            error("bw not valid");
        end
    else
        error("setting not valid");
    end

    bestshift = bestshifts(sf-4);
end

function [preamble_detect_run, errormap_run, errormap_sym_run, payload_error_run] = sim_intern( ...
    sfs, bw, cr, snr, fs_wifi, rf_freq, payload_length, payload_orig, symbols_test, ...
    jitter, known_delay, unknown_delay, wifi_mac, WiLo_packet_size, preamble_short, purlora,...
    show_spectrogram, plotting, overlap)

    preamble_detect_run = zeros(length(sfs),1);
    errormap_run = zeros(length(sfs), payload_length) + Inf;
    errormap_sym_run = zeros(length(sfs), length(symbols_test)) + Inf;
    payload_error_run = zeros(length(sfs),1) -1;

    for sf_i=1:length(sfs)
        sf = sfs(sf_i);
    
        shift = get_bestshift(sf,cr,bw,preamble_short, wifi_mac, overlap);
        
        if purlora
            [psdu_wave, symbols]= get_lora_nb_sym(sf, fs_wifi, payload_orig, cr, bw, rf_freq);
        else
            [psdu_wave, symbols] = wilo_packet_sim_symbol(sf, cr, bw, ...
                payload_orig, jitter, known_delay, ...
                unknown_delay, wifi_mac, shift, WiLo_packet_size, "std", preamble_short, ...
                overlap);
        end

        
        
        if isinf(snr)
            rx_wave = psdu_wave;
        else
            rx_wave = awgn(psdu_wave, snr);
        end
    
        % receive LoRa
        try
            [payload_rx, symbols_rx]=decode_lora_nb_sym(sf, fs_wifi, ...
                rx_wave, cr, bw, rf_freq); %psdu_wave(2000:end));
        catch
            payload_rx = [];

            symbols_rx = [];
        end
        
        preamble_detect_run(sf_i)  = ~isempty(payload_rx);
    
        if ~preamble_detect_run(sf_i)
            resultstr = "inval prmbl / hdr";
        end
    
        if length(payload_rx) >= length(payload_orig)
            errormap_run(sf_i,1:length(payload_orig)) = uint8(payload_rx(1:length(payload_orig))) -  uint8(payload_orig);
            payload_error_run(sf_i) = sum(errormap_run(sf_i,:)) / length(payload_orig);
    
            if payload_error_run(sf_i) == 0
                resultstr = "correct";
            else
                formatSpec = '%.2f';
                resultstr = strcat("payload error rate " + num2str(payload_error_run(sf_i),formatSpec));
            end
        end

        if length(symbols_rx) >= length(symbols)
            errormap_sym_run(sf_i,1:length(symbols)) = symbols_rx(1:length(symbols)) -  symbols;
        end
        
        disp(payload_rx);
    
        % show spectrogram
        if show_spectrogram && plotting
            subplot(ceil(length(sfs)/2),2,sf_i)
            pspectrum(psdu_wave,fs_wifi,'spectrogram');
            title(strcat("Wi-Lo SF=", int2str(sf), " (",resultstr, ")"));
        end
    
    end % for sf
end