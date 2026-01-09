import pyric
import pyric.pyw as pyw
import os
import argparse
from scapy.layers.dot11 import RadioTap, Dot11
from scapy.packet import Raw
from scapy.sendrecv import sendp
from scapy.utils import hexdump
from scapy.all import *
import numpy as np
import time
import pickle

LORA = "lora"
MPDU_max = 2304  # max number of bytes that can be sent including all headers
INTERVAL = 0.1

RT = Raw(bytes(
        [0x00, 0x00, 0x26, 0x00, 0x2f, 0x40, 0x00, 0xa0, 0x20, 0x08, 0x00, 0xa0, 0x20, 0x08, 0x00, 0x00,
        0xc7, 0xa7, 0x46, 0x01, 0x00, 0x00, 0x00, 0x00, 0x10, 0x16, 0x6c, 0x09, 0xa0, 0x00, 0xb7, 0x00,
        0x00, 0x00, 0xb7, 0x00, 0x00, 0x01
    ]))

def print_ifaces():
    print("We found these WiFi interfaces on your computer:")
    print('\n'.join(pyw.winterfaces()))

def prepare_iface(iface_name, channel):
    w0 = pyw.getcard(iface_name)

    if pyw.isup(w0):
        pyw.down(w0)

    if 'monitor' in pyw.devmodes(w0):
        pyw.modeset(w0, 'monitor')
    else:
        print("Can not use interface %s - monitor mode is not supported. %s only supports %s"%(w0.dev, w0.dev, ', '.join(pyw.devmodes(w0))))
        raise OSError(95, "Operation not supported", "Monitor mode is not supported by %s"% w0.dev)
    
    # pyw.chset(w0,channel,None) #TODO this line raises the device busy error
    pyw.up(w0)
    


def get_WiLo_payload(settings, payload):
    eng = matlab.engine.start_matlab()
    eng.cd(r'.', nargout=0)
    return eng.wilo_func(settings, payload)

parser = argparse.ArgumentParser(
            prog='Wi-Lo the WiFi to LoRa CTC',
            description='With the help of this program you can generate and transmit a frame to a LoRa device by using your WiFi card',
            epilog='(c) Sascha Rösler, Anatolij Zubow, Nils Einfeld\nTU Berlin 2024')

parser.add_argument('-I', '--list-interfaces', action='store_true', help="List all available interfaces")
parser.add_argument('-i', '--interface', default=None, help="Define the WiFi interface you want to use. Please make sure that packet injection in monitor mode is supported and that the card can inject CCK frames.")
parser.add_argument('-t', '--technology', default=LORA, choices=[LORA], help="The technology you want to send your message to (So far it is *lora*)")
parser.add_argument('-f', '--channel', type=int, default=1, choices=range(1,13), help="The WiFi channel in 2.4GHz you want to use")
parser.add_argument('-r', '--repetition', type=int, default=1, help="How often do you want to send the CTC frame")
parser.add_argument('-p', '--interval', type=float, default=1.0, help="The interval of the frames")
parser.add_argument('--scrambler', type=int, default=108, choices=range(1,127), help="The scrambler initialization value of your WiFi card. According to the standard this value is 108 which is the default value for WiLo. We also found that our Atheros WiFi card follows the standard and uses 108. However we saw that Realtek is using 52 as initialization value of the scrambler.")

parser.add_argument('-s', '--sf', type=int, default=5, choices=range(5,13), help="Spreading factor (SF) of the LoRa signal. Supported are SF5 - SF12")
parser.add_argument('-b', '--bw', type=int, default=1625, choices=[203, 406, 812, 1625], help="Bandwidth (BW) of the LoRa signal. Supported are 203, 406, 812, 1625")
parser.add_argument('-c', '--cr', type=int, default=1, choices=range(1,5), help="Code rate (CR) of the LoRa signal. It follows the formula $4 / (4 + CR)$. Supported are all integers between 1 and 4")

parser.add_argument("payload",nargs='+')

args = parser.parse_args()

print(args)

if args.list_interfaces:
    print_ifaces()
else:

    if args.interface is None:
        print("Please define an interface")
        print_ifaces()
        exit(-1)
    
    if args.payload is None:
        print("Please add the message you want to send")
        exit(-1)
    
    pipein, pipeout = os.pipe()
    ppid = os.getpid()
    
    child_pid = os.fork()
    
    # 
    # Start a child process that skipts the sudo rights
    # as MATLAB is not supposed to run as root
    #
    
    if child_pid == 0:
        
        os.setuid(int(os.environ['SUDO_UID']))
        
        import matlab.engine
        
        lora_settings = {
            'lora': {
                'sf': matlab.double(args.sf),
                'bw': matlab.double(args.bw * 1e3),
                'cr': matlab.double(args.cr),
                'frequency': matlab.double(2407e6 + 5e6 * args.channel)
            },
            'scrambler_init': args.scrambler
        }
        
        merged_payload = ' '.join(args.payload)
        
        wifi_frames = get_WiLo_payload(lora_settings, merged_payload)
        
        os.write(pipeout, pickle.dumps(wifi_frames))
        os.close(pipeout)
        
        print("MATLAB finished")
        exit(0)
    
    
    pid, status = os.waitpid(child_pid, 0)
    
    if not status == 0:
        print("MATLAB child process failed!")
        exit(status)
    
    print(status)
    prepare_iface(args.interface, args.channel)
    
    wifi_frames = pickle.loads(os.read(pipein, int(1e9)))
    
    for line in wifi_frames:
        byte_array = np.array(line)

        # experiments have shown that the max size is limited, need to subtract length of headers.
        # headers must be added, else the packet does not get send
        space_left = MPDU_max - len(RT)  # - len(dot11) #- len(ieee_header)
        byte_array_cut = byte_array[:space_left]

        pl = Raw(byte_array_cut.astype(np.uint8).tobytes())

        frame = RT / pl  # / ieee_header dot11 /
        print(f"Frame length: " + str(len(frame)))
        print(f"Payload length: " + str(len(pl)))
        print(f"Radiotap  length: " + str(len(RT)))
        print(f"space_left: " + str(space_left))
        print(f"Lost bytes: " + str(len(byte_array) - len(byte_array_cut)))
        hexdump(pl)

        #for j in range(args.repetition):
        sendp(frame, iface=args.interface, inter=args.interval, count=args.repetition)
    
