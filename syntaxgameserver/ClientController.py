import os
import subprocess
import time
import socket
import logging
import psutil
import win32gui
import win32con
import time
from UDPProxy import UDPProxy

def IsPortInUse( port : int ) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.1)
        portInUseResult = s.connect_ex(('127.0.0.1', port)) == 0
        return portInUseResult

class ClientController:
    """
        Used for controlling servers which we host off patched clients instead of normal RCCService
    """
    ExecutablePath = None
    Port = None
    Process = None
    AttachedUDPProxy = None
    JoinScriptUrl = None
    StartTimeout = 40
    
    def __init__(self, ExecutablePath : str, JoinscriptUrl : str = "", ExpectedPort : int = 53640, StartTimeout : int = 40):
        if IsPortInUse(ExpectedPort):
            raise Exception(f"Port {str(ExpectedPort)} is already in use")

        self.ExecutablePath = ExecutablePath
        self.Port = ExpectedPort
        self.JoinScriptUrl = JoinscriptUrl
        self.StartTimeout = StartTimeout

        self.Start( timeout = StartTimeout )

    def BindUDPProxy( self, proxyObj : UDPProxy ):
        if self.AttachedUDPProxy is not None:
            raise Exception("UDPProxy is already attached")
        if proxyObj is None:
            raise Exception("proxyObj is None")
        self.AttachedUDPProxy = proxyObj
    
    def Start(self, timeout : int = 40):
        """
            Starts the client
        """
        if self.Process is not None:
            raise Exception("Process is already started")
        if self.JoinScriptUrl is None:
            raise Exception("JoinScriptUrl is None")
        startupInfo = subprocess.STARTUPINFO()
        startupInfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startupInfo.wShowWindow = subprocess.SW_HIDE
        self.Process = subprocess.Popen([self.ExecutablePath, "-t", "None", "-j", self.JoinScriptUrl, "-a", "http://www.syntax.eco/Login/Negotiate.ashx"], stdout = subprocess.PIPE, stderr = subprocess.PIPE, startupinfo = startupInfo)
        time.sleep(7.5) # Client usually takes about 7.5 seconds to start up

        startTime = time.time()
        while True:
            if time.time() - startTime > timeout:
                raise Exception("Client failed to start in time")
            if self.Process.poll() is not None:
                raise Exception("Client process died")
            
            try:
                def EnumWindowsCallback( hwnd, lParam ):
                    if win32gui.GetWindowText(hwnd) == "ROBLOX":
                        win32gui.ShowWindow(hwnd, win32con.SW_MINIMIZE)
                        lParam.append(hwnd)
                    return True
                hwnds = []
                win32gui.EnumWindows(EnumWindowsCallback, hwnds)

                if len(hwnds) > 0:
                    break
            except:
                pass
            time.sleep(0.1)

        logging.info(f"Started client on port {str(self.Port)}")

    def Kill(self):
        """
            Kills the client
        """
        if self.Process is None:
            raise Exception("Process has not started")
        self.Process.kill()
        self.Process = None
        if self.AttachedUDPProxy is not None:
            self.AttachedUDPProxy.StopUDPProxy()
            self.AttachedUDPProxy = None

    def KillRCC(self):
        return self.Kill()
    
    def __del__(self):
        if self.Process is not None:
            self.Kill()