addpath("multi_packet_sim/");

jitter = 0;
known_delay = 0;
unknown_delay = 0;
wifi_mac=1;
shift = 0;
MAX_HW_BYTES = 2304;
mode = "std";
preamble_short = 0;
overlap = true;
cr = 1;
bw=1625e3;
sf=7;
fs_wifi = 11e6;
rf_freq = 2412e6;


settings = struct;

settings.lora = struct;

settings.lora.sf = sf;
settings.lora.bw = bw;
settings.lora.cr = cr;
settings.lora.shift = shift;
settings.lora.frequency = rf_freq;
settings.MAX_HW_BYTES = MAX_HW_BYTES;

settings.scrambler_init = 108;

settings.lora.mode = "std";
settings.overlap = true;


payload = "H";

wifi_payload = wilo_func(settings, payload);

waveform = get_lora_nb(sf,fs_wifi, uint8(convertStringsToChars(payload)),cr,bw,rf_freq);

psdu_wave = ctc_packet_sim(waveform, jitter, known_delay, ...
        unknown_delay, wifi_mac, shift, MAX_HW_BYTES, mode, preamble_short, ...
        overlap);

%%
test = [" ", " "];

fid = fopen('sf7_bytes_l200_overlap.txt','wt');
for i=1:size(wifi_payload, 2)
    disp("packet");
    test(i) = join(string(dec2hex(wifi_payload{i})), ", 0x");
    fprintf(fid, test(i));
    fprintf(fid, "\n");
    disp(test);
end
fclose(fid);