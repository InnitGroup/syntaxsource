import logging
import socket
import os
import subprocess

def IsPortInUse( port : int ) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.1)
        return s.connect_ex(('127.0.0.1', port)) == 0

class UDPProxy():
    """
        A wrapper for socat ( Linux ) and netcat ( Windows ) to forward UDP packets
    """
    UDPProxyProcess = None
    UDPProxyPort = 0
    UDPProxyTargetPort = 0
    UDPProxyTargetHost = "127.0.0.1"
    isRunning = False

    def __init__(self, UDPProxyPort : int, UDPProxyTargetPort : int, UDPProxyTargetHost : str = "127.0.0.1"):
        self.UDPProxyPort = UDPProxyPort
        self.UDPProxyTargetPort = UDPProxyTargetPort
        self.UDPProxyTargetHost = UDPProxyTargetHost
        
    def StartUDPProxy(self):
        if self.isRunning:
            logging.warning("UDPProxy is already running")
            return
        if IsPortInUse(self.UDPProxyPort):
            logging.warning(f"UDPProxyPort {self.UDPProxyPort} is already in use")
            return
        logging.info(f"Starting UDPProxy on port {self.UDPProxyPort} forwarding to {self.UDPProxyTargetHost}:{self.UDPProxyTargetPort}")
        # We need to handle multiple clients at once so we use fork
        if os.name == "nt":
            self.UDPProxyProcess = subprocess.Popen(["quilkin", "--no-admin", "proxy", "-p", str(self.UDPProxyPort), "-t", f"{self.UDPProxyTargetHost}:{self.UDPProxyTargetPort}"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        else:
            self.UDPProxyProcess = subprocess.Popen(["socat", "udp-listen:{},fork".format(self.UDPProxyPort), "udp:127.0.0.1:{}".format(self.UDPProxyTargetPort)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.isRunning = True

    def StopUDPProxy(self):
        if self.isRunning is False:
            logging.warning("UDPProxy is not running")
            return
        logging.info(f"Stopping UDPProxy on port {self.UDPProxyPort}")
        self.UDPProxyProcess.kill()
        self.isRunning = False

    def __del__(self):
        self.StopUDPProxy()

