% test.m

rf_freq = 2412e6;    % carrier frequency 470 MHz, used to correct clock drift
fs_wifi = 11e6;
wifi_mac = true;
show_spectrogram = true;

addpath("../perm/");
addpath("../");
addpath("../multi_packet_sim");

datapath = "data/";

DISABLE_IFS = true;
DISABLE_PLCP = false;

aCWmin = 31;
aCWmax = 1023;
aSlotTime = 20e-6; % [us]
aSIFSTime = 10e-6; % [us]
DIFS = aSIFSTime + 2* aSlotTime;
ifs = 0;


scrambler_init = 108;   % value according to the standard. Is different for Realtek cards

payload_length = 20;

sfs = 5:12;
bws = [203e3,406e3,812e3,1625e3];

preamble_detect = zeros(length(sfs),4) -1;
payload_error = zeros(length(sfs),4) -1;

%length_lora = ceil(length(lorawaveform_11) / 8);

used_mac_header = [];

if wifi_mac
    used_mac_header = get_wifi_bits();
end

payload_lengths = 1:100;

required_packets = zeros(length(sfs), 4, length(payload_lengths), 4);

for payload_length_i = 1:length(payload_lengths)

    payload_length = payload_lengths(payload_length_i);
    payload_orig = [1:payload_length];

    for cr= 1:4
        fig = figure;
        sgtitle(strcat("CR=4/", int2str(4+cr)));
    
        errormap = zeros(length(sfs), payload_length );
    
        for sf_i=1:length(sfs)
            sf = sfs(sf_i);
            for bw_i=1:length(bws)
                bw=bws(bw_i);
            
                % generate LoRa frame
                lorawaveform_11=get_lora_nb(sf, fs_wifi, payload_orig, cr, bw);
            
                % Wi-Lo
                cfgNonHT = wlanNonHTConfig('Modulation', 'DSSS', 'DataRate', '11Mbps', 'Preamble', 'Long', 'LockedClocks', true);
                bits = WiFi_bits(lorawaveform_11, used_mac_header, cfgNonHT, scrambler_init, DISABLE_IFS, DISABLE_PLCP); % generate bits that emulate the lora waveform
                assert(mod(length(bits),8)==0, "LoRa_Emulate_80211b did not return whole bytes");
                
                % send Wi-Lo frame
                cfgNonHT = wlanNonHTConfig('Modulation', 'DSSS', 'DataRate', '11Mbps', 'Preamble', 'Long', 'LockedClocks', true);
                cfgInfo = wlan.internal.dsssInfo(cfgNonHT);
                scrambInit = bit2int(cfgInfo.ScramblerInitialization', 7);
                            
                wifi_pkt_cnt = 0;
            
                for i=1:size(bits,1)
                    mybits = bits(i,:);
            
                    myend = find(mybits==-1,1,'first');
            
                    if isempty(myend)
                        myend = size(bits,2);
                    else
                        myend = myend -1;
                    end
            
                    if myend < 1
                        break;
                    end
                    
                    wifi_pkt_cnt = wifi_pkt_cnt + 1;
    
                end
                
                required_packets(sf_i, cr, payload_length_i, bw_i) = wifi_pkt_cnt;
            end
        end
    end

end

save(strcat(datapath, "wilo_requiredpackets.mat"), "required_packets");

%%

function lora_nb=get_lora_nb(sf, fs_wifi, payload, cr, bw)
    rf_freq = 2412e6;    % carrier frequency 470 MHz, used to correct clock drift
    fs_lora = bw*4;           % sampling rate 1 MHz
    
    
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

function wifi_mac_header=get_wifi_bits()
    mac_header_len = 36;
    beaconCfg = wlanMACFrameConfig(FrameType='Beacon');
    beaconCfg.FromDS = 0;
    
    % disp(beaconCfg);
    
    % Create a management frame-body configuration object
    frameBodyCfg = wlanMACManagementConfig;
    frameBodyCfg.BasicRates = {'1 Mbps', '11 Mbps'};
    
    % disp(frameBodyCfg);
    
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
    % beaconFrame = wlanMACFrame(beaconCfg);
    
    % Generate bits for a Beacon frame
    beaconFrameBits = wlanMACFrame(beaconCfg, OutputFormat='bits');
    
    wifi_mac_header = beaconFrameBits(1:mac_header_len * 8);
end
