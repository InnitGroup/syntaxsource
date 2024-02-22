import subprocess
import requests
import logging
import socket
import time
import threading
import platform
from UDPProxy import UDPProxy
from SOAPFormats import RCCSOAPMessages

def IsPortInUse( port : int ) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(0.1)
        return s.connect_ex(('127.0.0.1', port)) == 0

def isSystemLinux() -> bool:
    """
    Checks if the system is linux
    """
    return platform.system() == "Linux"

class InvalidRCCExecutablePath(Exception):
    pass
class PortAlreadyInUse(Exception):
    pass
class RCCNotStarted(Exception):
    pass
class RCCAlreadyRunning(Exception):
    pass

class RccController():
    RCCProcess = None
    RCCPort = 64989
    RCCExecutablePath = None
    SoapMessageFormatter = RCCSOAPMessages()
    KillRCCWhenFinished = True
    RCCKillerWatcherThread = None
    AttachedUDPProxy = None
    RCCVersion = "2016"

    def __init__(self, RCCExecutablePath, RCCPort = 64989, KillRCCWhenFinished : bool = True, RCCVersion : str = "2016", useVerbose : bool = False, PlaceIdStartupBypassOverwrite : int = 0 ):
        if RCCExecutablePath is None:
            raise InvalidRCCExecutablePath("RCCExecutablePath is Empty")
        if IsPortInUse(RCCPort):
            raise PortAlreadyInUse("RCCPort is already in use")
        if RCCVersion not in ["2016", "2018", "2020", "2021"]:
            raise Exception("RCCVersion is not valid")
        
        self.RCCVersion = RCCVersion
        self.RCCExecutablePath = RCCExecutablePath
        self.RCCPort = RCCPort
        self.KillRCCWhenFinished = KillRCCWhenFinished
        self.StartRCC(RCCPort, useVerbose = useVerbose, PlaceIdStartupBypassOverwrite = PlaceIdStartupBypassOverwrite)
    
    def __del__(self):
        if self.RCCProcess is not None:
            self.KillRCC()
    
    def BindUDPProxy(self, proxyObj : UDPProxy = None):
        if self.AttachedUDPProxy is not None:
            raise Exception("UDPProxy is already attached")
        if proxyObj is None:
            raise Exception("proxyObj is None")
        self.AttachedUDPProxy = proxyObj

    def PollRCC(self) -> bool:
        if self.RCCProcess is None:
            return False
        return self.RCCProcess.poll() is None

    def PingRCC(self) -> bool:
        if self.RCCProcess is None:
            return False
        if self.PollRCC() is False:
            return False
        try:
            requests.get(f"http://127.0.0.1:{str(self.RCCPort)}", timeout=1)
            return True
        except:
            return False
    
    def PingRCCUntilTimeout(self, interval : int = 0.05 , timeout : int = 25) -> bool:
        if self.RCCProcess is None:
            return False
        if self.PollRCC() is False:
            return False
        t = time.time()
        while time.time() - t < timeout:
            if self.PingRCC():
                return True
            time.sleep(interval)
        return False
    
    def StartRCC(self, RCCPort = 64989, stdout = None, stderr = None, useVerbose : bool = False, PlaceIdStartupBypassOverwrite : int = 0):
        if self.RCCProcess is not None:
            raise RCCAlreadyRunning("RCC is already running")
        logging.info(f"Starting RCCService on port {RCCPort}")
        if IsPortInUse(RCCPort):
            raise PortAlreadyInUse("RCCPort is already in use")
        logging.info(f"Starting RCCService Process ( Port: {str(RCCPort)} )")
        StartTime = time.time()
        if isSystemLinux():
            # Check if wine is installed
            if subprocess.call(["wine", "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL) != 0:
                raise Exception("Wine is not installed")
            StartingArguments = ["wine",self.RCCExecutablePath, f"{str(RCCPort)}", "-PlaceId:-1", "-Console"]
            if useVerbose:
                StartingArguments.append("-verbose")
            self.RCCProcess = subprocess.Popen(StartingArguments, stdout = stdout, stderr = stderr)
        else:
            StartingArguments = [self.RCCExecutablePath, f"{str(RCCPort)}", f"-PlaceId:{str(PlaceIdStartupBypassOverwrite)}", "-Console" ]
            if useVerbose:
                StartingArguments.append("-verbose")
            self.RCCProcess = subprocess.Popen(StartingArguments, stdout = stdout, stderr = stderr)
        logging.info(f"Waiting for RCCService to start ( Port: {str(RCCPort)} )")
        SuccessPoll = self.PingRCCUntilTimeout()
        if SuccessPoll is False:
            logging.error("Failed to start RCCService because timed out while waiting for it to start, killing process")
            self.KillRCC(throwException=False)
            raise Exception("Failed to start RCCService")
        logging.info(f"RCCService Started ( Port: {str(RCCPort)}, PID: {str(self.RCCProcess.pid)} ) Start Time: {str(round(time.time() - StartTime,3))}secs")
        if self.KillRCCWhenFinished:
            self.StartKillerWatcherThread()

    def KillRCC(self, throwException : bool = True):
        if self.RCCProcess is not None:
            logging.info(f"Killing RCCService Process ( {str(self.RCCProcess.pid)} )")
            self.RCCProcess.kill()
            self.RCCProcess = None

            if self.AttachedUDPProxy is not None:
                logging.info(f"Stopping UDPProxy attached to RCCService ( {str(self.AttachedUDPProxy.UDPProxyPort)} )")
                self.AttachedUDPProxy.StopUDPProxy()
                self.AttachedUDPProxy = None
        else:
            if throwException:
                raise RCCNotStarted("No RCC process is running")
    
    def SendRCCRequest(self, data = "", timeout : int = 5) -> requests.Response:
        if self.PingRCC() is False:
            return None
        try:
            return requests.post(f"http://127.0.0.1:{str(self.RCCPort)}", data=data, timeout=timeout)
        except:
            logging.error("Failed to send request to RCCService")
            return None

    def GetRunningJobs(self):
        if self.PingRCC() is False:
            return []
        RCCresponse : requests.Response = self.SendRCCRequest(self.SoapMessageFormatter.GetAllJobsMsg)
        
        if RCCresponse is None:
            return []
        if RCCresponse.status_code != 200:
            logging.error(f"Failed to get running jobs from RCCService, status code: {str(RCCresponse.status_code)}")
            return []
        if RCCresponse.text is None:
            logging.error("Failed to get running jobs from RCCService, response text is None")
            return []
        RunningJobs = self.SoapMessageFormatter.ParseGetAllJobsResponse(RCCresponse.text)
        return RunningJobs
    
    def SendOpenJobRequest( self, JobId : str , Expiration : int = 20, Cores : int = 1, ScriptName : str = "RunScript", RunScript : str = "", Arguments = [], requestTimeout : int = 5) -> requests.Response:
        if self.PingRCC() is False:
            raise RCCNotStarted("SendOpenJobRequest was called before RCC was started")
        OpenJobData : str = self.SoapMessageFormatter.FormatOpenJobMessage(JobId, Expiration, Cores, ScriptName, RunScript, Arguments)
        return self.SendRCCRequest(OpenJobData, timeout=requestTimeout)
    
    def SendBatchJobRequest( self, JobId : str , Expiration : int = 20, Cores : int = 1, ScriptName : str = "RunScript", RunScript : str = "", Arguments = [], requestTimeout : int = 5) -> requests.Response:
        if self.PingRCC() is False:
            raise RCCNotStarted("SendBatchJobRequest was called before RCC was started")
        BatchJobData : str = self.SoapMessageFormatter.FormatBatchJobMessage(JobId, Expiration, Cores, ScriptName, RunScript, Arguments)
        return self.SendRCCRequest(BatchJobData, timeout=requestTimeout)
    
    def SendCloseJobRequest(self, JobId : str) -> requests.Response:
        if self.PingRCC() is False:
            raise RCCNotStarted("SendCloseJobRequest was called before RCC was started")
        CloseJobData : str = self.SoapMessageFormatter.FormatCloseJobMessage(JobId)
        return self.SendRCCRequest(CloseJobData)
    
    def SendExecuteScriptRequest(self, JobId : str, ScriptName : str = "Script", Script : str = "", Arguments = []) -> requests.Response:
        if self.PingRCC() is False:
            raise RCCNotStarted("SendExecuteScriptRequest was called before RCC was started")
        ExecuteScriptData : str = self.SoapMessageFormatter.FormatExecuteScriptMessage(JobId, ScriptName, Script, Arguments)
        return self.SendRCCRequest(ExecuteScriptData)

    def StartKillerWatcherThread(self):
        if self.RCCKillerWatcherThread is not None:
            logging.warn("KillerWatcherThread is already running")
            return
        logging.info("Starting RCCService KillerWatcherThread")
        self.RCCKillerWatcherThread = threading.Thread(target=self.KillRCCAfterNoJobsThread)
        self.RCCKillerWatcherThread.start()

    def KillRCCAfterNoJobsThread(self, WaitTime : int = 2):
        if self.PingRCC() is False:
            return
        time.sleep(WaitTime)
        EmptyCount : int = 0
        while True:
            RunningJobs = self.GetRunningJobs()
            if len(RunningJobs) == 0:
                EmptyCount += 1
                if EmptyCount >= 2:
                    break
            time.sleep(1)
        if self.PingRCC() is False:
            return
        logging.info(f"No more running jobs, killing RCCService process ( PID: {str(self.RCCProcess.pid)} )")
        self.KillRCC()
