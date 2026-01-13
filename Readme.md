# Wi-Lo: The userspace CTC

This is Wi-Lo the userspace cross technology communication framework.
You can use it to transmit LoRa frames with the help of your WiFi card. 
Other hardware is not necessary.
You also don't have to change drivers on your machine.
However, `sudo` access is required as Wi-Lo is using packet injection.

## Requirements

First of all, you need a computer with root access.
Additionally, you need a WiFi card that supports packet injection in 802.11b CCK mode.
You also need an installed MATLAB instance.

## How to install
1. First of all, clone this git repository:
`git clone ???`
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


## How to run
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

## Contact
- Sascha Rösler, TU-Berlin, roesler@tkn
- Anatolij Zubow, TU-Berlin, zubow@tkn
- tkn = tkn.tu-berlin.de

## How to reference Wi-Lo?

## Acknowledgement
This work bases on the Wi-Lo of Gawlowicz et al. [1] and the Bachelor thesis of Nils Einfeld [2]

## References
[1] P. Gawłowicz, A. Zubow, and F. Dressler, “Wi-Lo: Emulation of LoRa using Commodity 802.11b WiFi Devices,” in IEEE ICC 2022, Seoul, South Korea: IEEE, May 2022, pp. 4414–4419.
[2] [1] N. Einfeldt, “Design of a Low-Cost Software-Defined Radio System Based on Waveform Emulation,” Bachelor Thesis, School of Electrical Engineering and Computer Science (EECS) / TU Berlin (TUB), Berlin, Germany, 2022.
