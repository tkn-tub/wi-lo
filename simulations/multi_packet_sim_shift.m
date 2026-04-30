% test.m

rf_freq = 2412e6;    % carrier frequency 470 MHz, used to correct clock drift
fs_wifi = 11e6;
show_spectrogram = false;
plotting = false;

addpath("../perm/");
addpath("../");
addpath("../multi_packet_sim");


datapath = "data/shift/";

DISABLE_IFS = true;
DISABLE_PLCP = false;

aCWmin = 31;
aCWmax = 1023;
aSlotTime = 20e-6; % [us]
aSIFSTime = 10e-6; % [us]
DIFS = aSIFSTime + 2* aSlotTime;
ifs = 0;

sfs = 5:9;
crs = [1,4];
bws = [203e3, 1625e3];
%crs = 1:4;
shifts = [0:180]*100;

jitter = 0;
known_delay = 0;
unknown_delay = 0;

wifi_mac = true;
WiLo_packet_size = 2304;

preamble_short = false;
overlap = true;

runs = 100;

fh = @wilo_packet_sim;
memoizedSim = memoize(fh);

plens = [1, 10, 20, 50, 100, 200];

for bw_i=1:length(bws)
    bw = bws(bw_i);
    for cr_i=1:length(crs)
        cr = crs(cr_i);
        for plen_i = 1:length(plens)
            payload_length = plens(plen_i);
            %payload_orig = [1:payload_length];
        
        
            preamble_detect = zeros(length(shifts),length(sfs)) -1;
            payload_error = zeros(length(shifts),length(sfs), runs) -1;
        
            if plotting
                fig = figure;
                sgtitle(strcat("payload = ", int2str(payload_length)));
            end
        
            for sf_i = 1:length(sfs)
        
                sf = sfs(sf_i);

                disp(strcat(int2str(bw), " ", int2str(cr), " ", int2str(sf)));
        
                errormap = zeros(length(shifts), payload_length );
        
                parfor shift_i = 1:length(shifts)
                    shift = shifts(shift_i);

                    for run=1:runs
                        payload_orig = randi([0,255],payload_length,1).';

                        psdu_wave = memoizedSim(sf, cr, bw, payload_orig, jitter, known_delay, ...
                                        unknown_delay, wifi_mac, shift, WiLo_packet_size, ...
                                        "std", preamble_short, overlap);
                    
                        % receive LoRa
                        try
                            payload_rx=decode_lora_nb(sf, fs_wifi, psdu_wave, cr, bw, rf_freq); %psdu_wave(2000:end));
                        catch
                            payload_rx = [];
                        end
                    
                        preamble_detect(shift_i, sf_i) = preamble_detect(shift_i, sf_i) + (~isempty(payload_rx));
                    
                        if ~preamble_detect(shift_i, sf_i)
                            resultstr = "inval prmbl / hdr";
                        end
                    
                        if length(payload_rx) >= length(payload_orig)
                            errormap_t = 1 - (payload_rx(1:length(payload_orig)) ==  payload_orig);
                            errormap(shift_i,:) = errormap(shift_i,:) + errormap_t;
                            payload_error(shift_i, sf_i, run) = sum(errormap_t) / length(payload_orig);
                    
                            if payload_error(shift_i, sf_i, run) == 0
                                resultstr = "correct";
                            else
                                formatSpec = '%.2f';
                                resultstr = strcat("payload error rate " + num2str(payload_error(shift_i, sf_i, run),formatSpec));
                            end
                        end
                        
                        disp(payload_rx);
                    
                        % show spectrogram
                        if show_spectrogram && ploting
                            subplot(ceil(length(shifts)/2),2,shift_i)
                            pspectrum(psdu_wave,fs_wifi,'spectrogram');
                            title(strcat("Wi-Lo Shift=", int2str(shift), " (",resultstr, ")"));
                        end
                    end
                
                end
                if show_spectrogram && plotting
                    saveas(fig, strcat(datapath, "wilo_spectrum_sf", int2str(sf), "_plen", ...
                        int2str(payload_length), ".pdf"));
                    saveas(fig, strcat(datapath, "wilo_spectrum_sf", int2str(sf), "_plen", ...
                        int2str(payload_length), ".fig"));
                end
                
                if plotting
                    clrmap = [1 1 1
                        1 0 0];
                    fig = figure;
                    heatmap(1:payload_length,shifts,errormap, "Colormap",clrmap); % , 
                    xlabel("symbol position");
                    ylabel("shift");
                    sgtitle(strcat("error map plen = ", int2str(payload_length)));
                    
                    saveas(fig, strcat(datapath, "wilo_errormap_sf", int2str(sf), "_plen", ...
                        int2str(payload_length), ".pdf"));
                    saveas(fig, strcat(datapath, "wilo_errormap_sf", int2str(sf), "_plen", ...
                        int2str(payload_length), ".fig"));
                end

                err_struct = struct("errormap", errormap);
                
                save(strcat(datapath, "wilo_errormap_sf", int2str(sf), "_plen", ...
                    int2str(payload_length), "_wifimac", int2str(wifi_mac), ...
                    "_shortpreamble", int2str(preamble_short), '_overlap', int2str(overlap), ...
                    "_sf",int2str(min(sfs)),"-", int2str(max(sfs)), ...
                    "_run",int2str(runs), ".mat"), "-fromstruct", err_struct);
            end
            
            if plotting
                fig = figure;
                bar(shifts, payload_error, 'BaseValue',-0.04);
                ylim([-0.04 max(payload_error, [], "all") + 0.05]);
                legend('CR = 4/5','CR = 4/6','CR = 4/7','CR = 4/8')
                xlabel("shift");
                ylabel("payload error rate");
                
                saveas(fig, strcat(datapath, "wilo_plen", int2str(payload_length), ".pdf"));
                saveas(fig, strcat(datapath, "wilo_plen", int2str(payload_length), ".fig"));
            end


            savestruct = struct( "payload_error",payload_error, "cr", cr, ...
                "bw",bw, "shifts",shifts, "sfs",sfs, "preamble_detect", preamble_detect, ...
                "runs", runs, "overlap", overlap);
            
            save(strcat(datapath, "wilo_payloaderror_plen", int2str(payload_length), ...
                 "_cr", int2str(cr), "_bw", int2str(bw), "_wifimac", int2str(wifi_mac), ...
                 "_shortpreamble", int2str(preamble_short), '_overlap', int2str(overlap) , ...
                 "_sf",int2str(min(sfs)),"-", int2str(max(sfs)), ...
                 "_run",int2str(runs), ".mat"), ...
                 "-fromstruct", savestruct);
            %save(strcat(datapath, "wilo_preambledetect_plen", int2str(payload_length), ...
            %     "_cr", int2str(cr),  "_bw", int2str(bw), ".mat"), "-fromstruct", "preamble_detect", "cr", "bw", "shifts", "sfs");
        end
    end
end
