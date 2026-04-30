# Wi-Lo: The userspace CTC

This is Wi-Lo the userspace cross technology communication framework.
You can use it to transmit LoRa frames with the help of your WiFi card. 
However, this repository includes two parts of our implementation.
1. The full framework to emulate SF5 and SF6 LoRa waveforms in the 2.4GHz band.
1. We also provide our software to emulate SF>6 in simulations and to calculate the required WiFi packets. However, due to the requirement of a strict timing, this packets can not be send out by a normal WiFi card, but it is possible to send them with modified hardware. We demonstrated its feasibility by two synchronized modified Atheros chips based on the Firmware of Vanhoef et al. [3]. We provide the firmware on request.
For SF<7 there is no specialized hardware required.
You also don't have to change drivers on your machine.
However, `sudo` access is required as Wi-Lo is using packet injection.

## Requirements

First of all, you need a computer with root access.
Additionally, you need a WiFi card that supports packet injection in 802.11b CCK mode.
You also need an installed MATLAB instance.

## Full framework for SF<7

### How to install
1. First of all, clone this git repository:
`git clone https://github.com/tkn-tub/wi-lo.git`
1. Next, create a virtual environment in the repository directory. It is important to name your environment `venv`. Otherwise the Wi-Lo script will miss it.
`python3 -m venv venv`
1. Start your virtual python environment:
`source venv/bin/activate`
1. Next check your MATLAB version and find the MATLAB engine version accordingly. [pypi.org](https://pypi.org/project/matlabengine/#history) will help you.
1. Change the matlab engine version in `requirements.txt` to the one that fits your MATLAB
1. Install all the required python packages
`pip install -r requirements.txt`
1. In case the installation fails because your MATLAB installation is not found add the path to your virtual environment Therefore add `export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:PATH/TO/YOUR/MATLAB/bin/glnxa64` to the file `venv/bin/activate`
   1. Close the virtual environment
`deactivate`
   1. Start the environment again
`soure venv/bin/activate`
   1. Start the installation again
`pip install -r requirements.txt`
1. And you are done :)


### How to run 
To send a Wi-Lo frame, please make sure that the WiFi card is connected with your computer.
Now, you can run `sudo -s -E ./wilo.sh -I` to list all connected WiFi cards.
To now run Wi-Lo you have to type `sudo -s -E ./wilo.sh -i THE_WIFI_CARD 'This is my message for LoRa'`.
For packet injection, you have to run the script with `sudo`. Please add `-s -E` such that all paths are set correctly.
You can add these arguments when running the script:
- `-i` The name of the WiFi interface you want to use
- `-t` The technology you want to send your message to (So far it is *lora*)
- `-f` The WiFi channel in 2.4GHz you want to use
- `-r` How often do you want to send the CTC frame
- `-p` The interval of the frames
- `scrambler` The scrambler initialization value of your WiFi card. According to the standard this value is 108 which is the default value for WiLo. We also found that our Atheros WiFi card follows the standard and uses 108. However we saw that Realtek is using 52 as initialization value of the scrambler.
- LoRa spicific parameters
  -  `-s` Spreading factor (SF) of the LoRa signal. Supported are SF5 - SF12
  -  `-b` Bandwidth (BW) of the LoRa signal. Supported are 203, 406, 812, 1625
  -  `-c` Code rate (CR) of the LoRa signal. It follows the formula $$4 / (4 + CR)$$. Supported are all integers between 1 and 4

## Full framework for SF>6
For SF>6 a multi-packet emulation is required which comes with several pitfalls. 
As this can not be easily done with any hardware, we have a firmware modification based on [3] we provide on request.
Nevertheless, we provide our userland implementations including simulation and calculation of the required WiFi payloads.

### Get WiFi payload
To calculate the WiFi payload you have to burn into your firmware later on, you can execute the `wilo_func_overlap.m` script.
Depending on your hardware, you can choose if you send the WiFi packets in an overlapping (Wi-Lo++ Double) way or after each other (Wi-Lo++ Single).
You can also choose if you like to transmit a vali WiFi header (required by some WiFi NICs) and the maximum PSDU length supported by your system.
Also the preamble mode can be chosen.

### Simulations
We also provide the code we used to simulate the performance of Wi-Lo++ in `simulations`.
- `multi_packet_count.m`: Calculation of the required WiFi packets needed to emulate one LoRa packet
- `multi_packet_sim_shift.m`: Finding suitable shifts for Wi-Lo++ Single to overcome distortions by the additional WiFi headers
- `multi_packet_sim_snr_func.m`: A SNR study for Wi-Lo++ under different configurations. 
- `multi_packet_sim_unknowndelay_func.m`: A study of the influence of failed synchronization. There is an additional constant delay to all WiFi packets unknown to the Wi-Lo++ calculation.
- `multi_packet_sim_knowndelay_func.m`: A study of the influence an additional delay which Wi-Lo++ will take into account.
- `multi_packet_sim_jitter_func.m`: A study of the influence of jittering within the synchronization. There is an randomized Gaussian distributed delay calculated for each WiFi packet. This delay is unknown to the Wi-Lo++ calculation.
- `multi_packet_sim_plen_func.m`: A study of which packet length Wi-Lo++ can successfully emulate.
The functions take different configuration parameters as list to allow internal loops.
This makes evaluation of different parameters possible.
There is also a `purlora` mode provided to get the data for non-emulated LoRa.


## Contact
- Sascha Rösler, TU-Berlin, roesler@tkn
- Anatolij Zubow, TU-Berlin, zubow@tkn
- Falko Dressler, TU-Berlin, dressler@tkn
- tkn = tkn.tu-berlin.de

## How to reference Wi-Lo?

## Acknowledgement
This work bases on the Wi-Lo of Gawlowicz et al. [1] and the Bachelor thesis of Nils Einfeld [2]

## References
[1] P. Gawłowicz, A. Zubow, and F. Dressler, “Wi-Lo: Emulation of LoRa using Commodity 802.11b WiFi Devices,” in IEEE ICC 2022, Seoul, South Korea: IEEE, May 2022, pp. 4414–4419.
[2] [1] N. Einfeldt, “Design of a Low-Cost Software-Defined Radio System Based on Waveform Emulation,” Bachelor Thesis, School of Electrical Engineering and Computer Science (EECS) / TU Berlin (TUB), Berlin, Germany, 2022.
[3] M. Vanhoef and F. Piessens, “Advanced Wi-Fi Attacks Using Commodity Hardware,” in 30th Annual Computer Security Applications Conference (ACSAC 2014), New Orleans, LA: ACM, Dec. 2014, pp. 256–265.
