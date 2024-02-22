import requests
import queue
import logging
import time
import threading
import uuid
import base64
from flask import Flask, request, jsonify
import psutil
import re
import io
import random
from PIL import Image
import gzip
import os
import json
import xmltodict
from SOAPFormats import RCCSOAPMessages
from ProcessController import RccController, IsPortInUse
from ClientController import ClientController
from UDPProxy import UDPProxy
import sys
import win32gui
import win32con
import winreg

try:
    from config import Config
except:
    if os.path.exists("C:\\Users\\Administrator\\config.py"):
        sys.path.append("C:\\Users\\Administrator")
        from config import Config

app = Flask(__name__)
config = Config()
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger('werkzeug')
log.setLevel(logging.ERROR)

thumbnailQueue = queue.Queue()
RCCReturnAuth = None
StopThreads = False
RunningJobs = {}
AvailableJobs = []
AvailableJobs2018 = []
AvailableJobs2020 = []
AvailableJobs2021 = []

GetNextPortMutex = threading.Lock()
GetNextRCCInstanceMutex = threading.Lock()
RCCComPort = config.RCCStartingComPort

def ReadAccessKey():
    """ Computer\HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\ROBLOX Corporation\Roblox\AccessKey """
    try:
        key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\ROBLOX Corporation\Roblox", 0, winreg.KEY_READ)
        value, _ = winreg.QueryValueEx(key, "AccessKey")
        winreg.CloseKey(key)
        return value
    except:
        return ""
    
def WriteAccessKey( value : str ):
    try:
        key = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\ROBLOX Corporation\Roblox", 0, winreg.KEY_SET_VALUE)
        winreg.SetValueEx(key, "AccessKey", 0, winreg.REG_SZ, value)
        winreg.CloseKey(key)
    except Exception as e:
        logging.error(f"WriteAccessKey : Failed to write AccessKey to registry, {str(e)}")
        pass

def GetNextAvailablePort(startingPort : int, endingPort : int) -> int:
    global RCCComPort
    """
    Gets the next available port in the range
    """
    GetNextPortMutex.acquire(timeout=20)

    # Check if the com port is open
    RCCComPort = random.randint(startingPort, endingPort)
    if not IsPortInUse(RCCComPort):
        GetNextPortMutex.release()
        return RCCComPort
    else:
        GetNextPortMutex.release()
        logging.info(f"Port {str(RCCComPort)} is not open, trying again")
        return GetNextAvailablePort(startingPort, endingPort)

def RefillAvailableJobs():
    global AvailableJobs
    global AvailableJobs2018
    global AvailableJobs2020

    GetNextRCCInstanceMutex.acquire(timeout=20)
    if len(AvailableJobs) > 1 and len(AvailableJobs2018) > 2:
        GetNextRCCInstanceMutex.release()
        return
    while len(AvailableJobs) < 1:
        AvailableJobs.append(RccController(config.RCCServicePath, GetNextAvailablePort(config.RCCStartingComPort, config.RCCEndingComPort), KillRCCWhenFinished=False, PlaceIdStartupBypassOverwrite = 1))
    while len(AvailableJobs2018) < 1:
        AvailableJobs2018.append(RccController(config.RCCService2018Path, GetNextAvailablePort(config.RCCStartingComPort, config.RCCEndingComPort), KillRCCWhenFinished=False, RCCVersion="2018", useVerbose=True))
    while len(AvailableJobs2020) < 1:
        AvailableJobs2020.append(RccController(config.RCCService2020Path, GetNextAvailablePort(config.RCCStartingComPort, config.RCCEndingComPort), KillRCCWhenFinished=False, RCCVersion="2020", useVerbose=True))
    while len(AvailableJobs2021) < 1:
        AvailableJobs2021.append(RccController(config.RCCService2021Path, GetNextAvailablePort(config.RCCStartingComPort, config.RCCEndingComPort), KillRCCWhenFinished=False, RCCVersion="2021", useVerbose=True))

    GetNextRCCInstanceMutex.release()
    return

def GetNextAvailableRCCInstance( version : str = "2016", startKillerWatcherThread : bool = True ) -> RccController:
    global AvailableJobs
    global AvailableJobs2018
    """
    Gets the next available RCC instance
    """
    GetNextRCCInstanceMutex.acquire(timeout=20)
    if version == "2016":
        if len(AvailableJobs) == 0:
            GetNextRCCInstanceMutex.release()
            threading.Thread(target=RefillAvailableJobs).start()
            return RccController(config.RCCServicePath,GetNextAvailablePort(config.RCCStartingComPort, config.RCCEndingComPort), KillRCCWhenFinished=startKillerWatcherThread, PlaceIdStartupBypassOverwrite = 1)
        AvailableInstance : RccController = AvailableJobs.pop(0)
        GetNextRCCInstanceMutex.release()
    elif version == "2018":
        if len(AvailableJobs2018) == 0:
            GetNextRCCInstanceMutex.release()
            threading.Thread(target=RefillAvailableJobs).start()
            return RccController(config.RCCService2018Path,GetNextAvailablePort(config.RCCStartingComPort, config.RCCEndingComPort), KillRCCWhenFinished=startKillerWatcherThread, RCCVersion="2018", useVerbose=True)
        AvailableInstance : RccController = AvailableJobs2018.pop(0)
        GetNextRCCInstanceMutex.release()
    elif version == "2020":
        if len(AvailableJobs2020) == 0:
            GetNextRCCInstanceMutex.release()
            threading.Thread(target=RefillAvailableJobs).start()
            return RccController(config.RCCService2020Path,GetNextAvailablePort(config.RCCStartingComPort, config.RCCEndingComPort), KillRCCWhenFinished=startKillerWatcherThread, RCCVersion="2020", useVerbose=True)
        AvailableInstance : RccController = AvailableJobs2020.pop(0)
        GetNextRCCInstanceMutex.release()
    elif version == "2021":
        if len(AvailableJobs2021) == 0:
            GetNextRCCInstanceMutex.release()
            threading.Thread(target=RefillAvailableJobs).start()
            return RccController(config.RCCService2021Path,GetNextAvailablePort(config.RCCStartingComPort, config.RCCEndingComPort), KillRCCWhenFinished=startKillerWatcherThread, RCCVersion="2021", useVerbose=True)
        AvailableInstance : RccController = AvailableJobs2021.pop(0)
        GetNextRCCInstanceMutex.release()
    
    if startKillerWatcherThread:
        AvailableInstance.StartKillerWatcherThread()

    threading.Thread(target=RefillAvailableJobs).start()
    return AvailableInstance

def thumbnailQueueWorker( workerNumber: int ):
    global RunningJobs
    random.seed(str(uuid.uuid4()) + str(workerNumber))
    InstanceController : RccController = GetNextAvailableRCCInstance( version = "2020", startKillerWatcherThread = False)
    RCCRenders : int = 0
    while True:
        try:
            if thumbnailQueue.empty():
                time.sleep(0.02)
                continue
            if StopThreads:
                break
            ThumbnailRequestInfo = thumbnailQueue.get()
            logging.info(f"Processing thumbnail request: {ThumbnailRequestInfo['reqid']}, remaining queue size: {str(thumbnailQueue.qsize())}")
            ThumbnailType = ThumbnailRequestInfo['type'] # 0 = PlayerThumbnail, 1 = PlayerHeadshot, 2 = Shirt or Pants, 3 = Assets ( Hats, Models etc.), 4 = Meshes

            ExecuteJSON = None
            Arguments = []
            Expiration = 10

            if ThumbnailType == 0:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Avatar",
                        "Arguments": [
                            f"{config.BaseURL}/v1/avatar-fetch?placeId=0&userId={ThumbnailRequestInfo['userid']}",
                            config.BaseURL,
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y']
                        ]
                    }
                }
            elif ThumbnailType == 1:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Closeup",
                        "Arguments": [
                            config.BaseURL,
                            f"{config.BaseURL}/v1/avatar-fetch?placeId=0&userId={ThumbnailRequestInfo['userid']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            True,
                            30,
                            100,
                            0,
                            0
                        ]
                    }
                }
            elif ThumbnailType == 2:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Avatar",
                        "Arguments": [
                            config.BaseURL,
                            f"{config.BaseURL}/v1/avatar-fetch/custom?assetId={ThumbnailRequestInfo['asset']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                        ]
                    }
                }
            elif ThumbnailType == 3:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Model",
                        "Arguments": [
                            f"{config.BaseURL}/asset/?id={ThumbnailRequestInfo['asset']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            config.BaseURL
                        ]
                    }
                }
            elif ThumbnailType == 4:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Mesh",
                        "Arguments": [
                            f"{config.BaseURL}/asset/?id={ThumbnailRequestInfo['asset']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            config.BaseURL
                        ]
                    }
                }
            elif ThumbnailType == 5:
                Expiration = 30
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Place",
                        "Arguments": [
                            f"{config.BaseURL}/asset/?id={ThumbnailRequestInfo['asset']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            config.BaseURL
                        ]
                    }
                }
            elif ThumbnailType == 6:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Image",
                        "Arguments": [
                            ThumbnailRequestInfo['asset'],
                            config.BaseURL,
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y']
                        ]
                    }
                }
            elif ThumbnailType == 7:
                r = requests.get(config.BaseURL + f"/Asset/?id={str(ThumbnailRequestInfo['asset'])}&access={ReadAccessKey()}", headers={"Requester": "Server"})
                if r.status_code != 200:
                    logging.error(f"Error downloading TShirt asset, id: {ThumbnailRequestInfo['asset']}, status code: {r.status_code}, response: {r.text}")
                    continue
                ImageURL = re.search(r"id=(\d+)", r.text)
                if not ImageURL:
                    ImageURL = re.search(r"rbxassetid:\/\/(\d+)", r.text)
                    if not ImageURL:
                        logging.error(f"Error finding TShirt image url, id: {ThumbnailRequestInfo['asset']}, status code: {r.status_code}, response: {r.text}")
                        continue
                ImageId = ImageURL.group(1)
                r = requests.get(f"{config.BaseURL}/asset/?id={ImageId}&access={ReadAccessKey()}", headers={"Requester": "Server"})
                if r.status_code != 200:
                    logging.error(f"Error downloading TShirt image, id: {ThumbnailRequestInfo['asset']}, status code: {r.status_code}, response: {r.text}")
                    continue
                with open("./TeeShirtTemplate.png", 'rb') as bg_file:
                    TShirtBG = bg_file.read()
                bg_image = Image.open(io.BytesIO(TShirtBG))
                content_image = Image.open(io.BytesIO(r.content))
                width, height = content_image.size
                aspect_ratio = width / height
                if width > height:
                    new_width = 250
                    new_height = int(new_width / aspect_ratio)
                else:
                    new_height = 250
                    new_width = int(new_height * aspect_ratio)

                content_image = content_image.resize((new_width, new_height), Image.LANCZOS)
                content_image = content_image.convert("RGBA")

                composite_image = Image.new('RGBA', bg_image.size)
                composite_image.paste(bg_image, (0, 0))
                mask = content_image.split()[3]
                composite_image.paste(content_image, (85, 85), mask=mask)

                composite_image_buffer = io.BytesIO()
                composite_image.save(composite_image_buffer, format='PNG')
                composite_image_buffer.seek(0)

                # Lets just return it to ourselves
                r = requests.post(
                    f"http://127.0.0.1:{str(config.CommPort)}/ThumbnailReturn?RCCReturnAuth={RCCReturnAuth}",
                    data = base64.b64encode(composite_image_buffer.getvalue()).decode('utf-8') + "|" + str(ThumbnailRequestInfo['reqid']) + "|" + str(ThumbnailRequestInfo['starttime'])
                )
                continue
            elif ThumbnailType == 8:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Head",
                        "Arguments": [
                            f"{config.BaseURL}/asset/?id={ThumbnailRequestInfo['asset']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            config.BaseURL,
                            1785197
                        ]
                    }
                }
            elif ThumbnailType == 9:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "BodyPart",
                        "Arguments": [
                            f"{config.BaseURL}/asset/?id={ThumbnailRequestInfo['asset']}",
                            config.BaseURL,
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            "http://www.roblox.com/asset/?id=1785197",

                        ]
                    }
                }
            elif ThumbnailType == 11:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Hat",
                        "Arguments": [
                            f"{config.BaseURL}/asset/?id={ThumbnailRequestInfo['asset']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            config.BaseURL
                        ]
                    }
                }
            elif ThumbnailType == 12:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Gear",
                        "Arguments": [
                            f"{config.BaseURL}/asset/?id={ThumbnailRequestInfo['asset']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            config.BaseURL
                        ]
                    }
                }
            elif ThumbnailType == 13:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "MeshPart",
                        "Arguments": [
                            f"{config.BaseURL}/asset/?id={ThumbnailRequestInfo['asset']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            config.BaseURL
                        ]
                    }
                }
            elif ThumbnailType == 14:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Pants",
                        "Arguments": [
                            f"{config.BaseURL}/asset/?id={ThumbnailRequestInfo['asset']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            config.BaseURL,
                            1785197
                        ]
                    }
                }
            elif ThumbnailType == 15:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Shirt",
                        "Arguments": [
                            f"{config.BaseURL}/asset/?id={ThumbnailRequestInfo['asset']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            config.BaseURL,
                            1785197
                        ]
                    }
                }
            elif ThumbnailType == 16:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Avatar_R15_Action",
                        "Arguments": [
                            config.BaseURL,
                            f"{config.BaseURL}/v1/avatar-fetch?placeId=0&userId={ThumbnailRequestInfo['userid']}",
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y']
                        ]
                    }
                }
            elif ThumbnailType == 17:
                ExecuteJSON = {
                    "Mode": "Thumbnail",
                    "Settings": {
                        "Type": "Package",
                        "Arguments": [
                            ThumbnailRequestInfo['asset'],
                            config.BaseURL,
                            "PNG",
                            ThumbnailRequestInfo['image_x'],
                            ThumbnailRequestInfo['image_y'],
                            "http://www.syntax.eco/asset/?id=1785197",
                            ""
                        ]
                    }
                }
            else:
                logging.error("Invalid thumbnail type")
                continue
            if RCCRenders >= 5 or InstanceController.PingRCC() is False:
                try:
                    InstanceController.KillRCC()
                except:
                    pass
                InstanceController = GetNextAvailableRCCInstance( version = "2020", startKillerWatcherThread = False)
                RCCRenders = 0

            ThumbnailJobId = str(uuid.uuid4())
            OpenResponse : requests.Response = InstanceController.SendBatchJobRequest(JobId=ThumbnailJobId, Expiration=Expiration, Cores=1, ScriptName="Render", Arguments=Arguments, RunScript=json.dumps(ExecuteJSON), requestTimeout=Expiration+5)
            RCCRenders += 1
            if OpenResponse is None:
                logging.error("Failed to send BatchJob request")
                continue
            if OpenResponse.status_code != 200:
                logging.error(f"Failed to send BatchJob request, status code: {str(OpenResponse.status_code)}, response: {OpenResponse.text}")
                continue

            Base64Image = None
            Response = xmltodict.parse(OpenResponse.text.strip())["SOAP-ENV:Envelope"]["SOAP-ENV:Body"]["ns1:BatchJobResponse"]["ns1:BatchJobResult"]
            if type(Response) == list:
                for ResponseItem in Response:
                    if ResponseItem["ns1:type"] == "LUA_TSTRING":
                        Base64Image = ResponseItem["ns1:value"]
            else:
                if Response["ns1:type"] == "LUA_TSTRING":
                    Base64Image = Response["ns1:value"]
            if Base64Image is None:
                logging.error("Failed to get image from BatchJob response")
                continue

            # Send it back to ourselves
            uploadReq = requests.post(
                f"http://127.0.0.1:{str(config.CommPort)}/ThumbnailReturn?RCCReturnAuth={RCCReturnAuth}",
                data = Base64Image + "|" + str(ThumbnailRequestInfo['reqid']) + "|" + str(ThumbnailRequestInfo['starttime'])
            )
            #InstanceController.KillRCC()
        except KeyboardInterrupt:
            break
        except Exception as e:
            logging.error(f"Error in thumbnailQueueWorker: {e}")
        time.sleep(0.02)

@app.route("/ThumbnailReturn", methods=["POST"])
def ThumbnailReturn():
    # Exepcted data:
    # base64 encoded png image|reqid
    try:
        if request.headers.get("Content-Encoding") == "gzip":
            data = gzip.decompress(request.data).decode("utf-8")
        else:
            data = request.data.decode("utf-8")
        data = data.split("|")
        reqid = data[1]
        imgdata = data[0]
        startime = float(data[2])
        data = base64.b64decode(imgdata)
        logging.info(f"Thumbnail returned for request {reqid}, took: {str(round(time.time() - startime, 2))} seconds")
        req = requests.post(
            config.BaseURL + "/internal/thumbnailreturn",
            headers={
                "Authorization": ReadAccessKey(),
                "ReturnUUID": reqid,
                "Content-Type": "image/png"
            },
            data=data
        )
        return "OK", 200
    except Exception as e:
        logging.error(f"Error in ThumbnailReturn: {e}")
        return "Error", 500

from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

def verify_signature( signature : bytes, data : bytes ) -> bool:
    with open("rsa_public_gameserver.pub", "rb") as key_file:
        public_key = serialization.load_pem_public_key(
            key_file.read(),
            backend=default_backend()
        )
    
    try:
        public_key.verify(
            signature,
            data,
            padding.PKCS1v15(),
            hashes.SHA256()
        )
        return True
    except:
        return False

@app.before_request
def CheckAuthorization():
    RCCReturnAuthReq = request.args.get("RCCReturnAuth")
    if RCCReturnAuthReq != RCCReturnAuth:
        ReqUserAgent = request.headers.get("User-Agent", default = "Unknown")
        if "SYNTAX-Gameserver-Communication/1.0" != ReqUserAgent:
            logging.error(f"Unauthorized request from {request.remote_addr} with User-Agent: {ReqUserAgent}")
            return "Unauthorized", 401
        RequestSignature = request.headers.get("X-Syntax-Request-Signature", default = None) 
        if RequestSignature is None:
            logging.error(f"Unauthorized request from {request.remote_addr} has no Request Signature")
            return "Unauthorized", 401
        
        try:
            ReqTimestamp, ReqSignature = RequestSignature.split("|")
            ReqTimestamp = float(ReqTimestamp)
            if time.time() - ReqTimestamp > 20:
                logging.error(f"Unauthorized request from {request.remote_addr} has expired Request Signature")
                return "Unauthorized", 401
            ReconstructuedData = f"{str(ReqTimestamp)}\n{request.method}"
            if request.method == "POST":
                ReconstructuedData += f"\n{request.data.decode('utf-8')}"
            ReqSignature = base64.b64decode(ReqSignature)
            if not verify_signature( ReqSignature, ReconstructuedData.encode('utf-8') ):
                logging.error(f"Unauthorized request from {request.remote_addr} has invalid Request Signature")
                return "Unauthorized", 401
        except Exception as e:
            logging.error(f"Error parsing Request Signature: {e}")
            return "Unauthorized", 401

@app.route("/AssetValidation2016", methods=["POST"])
def AssetValidation2016():
    """
        Expected JSON Data:
        {
            "assetid": 1,
        }
    """
    try:
        InstanceController : RccController = GetNextAvailableRCCInstance()
        ThumbnailJobId = str(uuid.uuid4())
        with open("./Scripts/PlaceValidation.lua", "r") as f:
            script = f.read()
        
        OpenResponse : requests.Response = InstanceController.SendBatchJobRequest(
            JobId=ThumbnailJobId,
            Expiration=40,
            Cores=1,
            ScriptName="PlaceValidation",
            Arguments=[
                request.json['assetid'],
                config.BaseURL,
                ReadAccessKey()
            ],
            RunScript=script,
            requestTimeout=45
        )
        if OpenResponse is None:
            logging.error("Failed to send OpenJob request")
            return "Error", 500
        if OpenResponse.status_code != 200:
            logging.error(f"Failed to send OpenJob request, status code: {str(OpenResponse.status_code)}, response: {OpenResponse.text}")
            return "Error", 500
        # Should only return one value which is either True as a bool or The reason as a string
        PlaceValidationResponse = xmltodict.parse(OpenResponse.text.strip())["SOAP-ENV:Envelope"]["SOAP-ENV:Body"]["ns1:BatchJobResponse"]["ns1:BatchJobResult"]
        if type(PlaceValidationResponse) == list:
            for ResponseItem in PlaceValidationResponse:
                if ResponseItem["ns1:type"] == "LUA_TBOOLEAN":
                    return jsonify({
                        "valid": ResponseItem["ns1:value"] == "true"
                    })
                elif ResponseItem["ns1:type"] == "LUA_TSTRING":
                    return jsonify({
                        "valid": False,
                        "reason": ResponseItem["ns1:value"]
                    })
        else:
            if PlaceValidationResponse["ns1:type"] == "LUA_TBOOLEAN":
                return jsonify({
                    "valid": PlaceValidationResponse["ns1:value"] == "true"
                })
            elif PlaceValidationResponse["ns1:type"] == "LUA_TSTRING":
                return jsonify({
                    "valid": False,
                    "reason": PlaceValidationResponse["ns1:value"]
                })
        logging.error(f"Failed to get response from OpenJob request to RCCService, status code: {str(OpenResponse.status_code)}, response: {OpenResponse.text}")
        return "Error", 500

    except Exception as e:
        logging.error(f"Error in AssetValidation2016: {e}")
        return "Error", 500

@app.route("/AssetValidation2018", methods=["POST"])
def AssetValidation2018():
    """
        Expected JSON Data:
        {
            "assetid": 1,
        }
    """
    try:
        ExecuteJSON = {
            "Mode": "Thumbnail",
            "Settings": {
                "Type": "PlaceValidation",
                "Arguments": [
                    f"{config.BaseURL}/asset/?id={request.json['assetid']}",
                    config.BaseURL
                ]
            }
        }

        InstanceController : RccController = GetNextAvailableRCCInstance( version = "2018" )
        ThumbnailJobId = str(uuid.uuid4())
        OpenResponse : requests.Response = InstanceController.SendBatchJobRequest(JobId=ThumbnailJobId, Expiration=40, Cores=1, ScriptName="Validation", Arguments=[], RunScript=json.dumps(ExecuteJSON), requestTimeout=45)
        if OpenResponse is None:
            logging.error("Failed to send OpenJob request")
            return "Error", 500
        if OpenResponse.status_code != 200:
            logging.error(f"Failed to send OpenJob request, status code: {str(OpenResponse.status_code)}, response: {OpenResponse.text}")
            return "Error", 500
        # Should only return one value which is either True as a bool or The reason as a string
        PlaceValidationResponse = xmltodict.parse(OpenResponse.text.strip())["SOAP-ENV:Envelope"]["SOAP-ENV:Body"]["ns1:BatchJobResponse"]["ns1:BatchJobResult"]
        if type(PlaceValidationResponse) == list:
            for ResponseItem in PlaceValidationResponse:
                if ResponseItem["ns1:type"] == "LUA_TBOOLEAN":
                    return jsonify({
                        "valid": ResponseItem["ns1:value"] == "true"
                    })
                elif ResponseItem["ns1:type"] == "LUA_TSTRING":
                    return jsonify({
                        "valid": False,
                        "reason": ResponseItem["ns1:value"]
                    })
        else:
            if PlaceValidationResponse["ns1:type"] == "LUA_TBOOLEAN":
                return jsonify({
                    "valid": PlaceValidationResponse["ns1:value"] == "true"
                })
            elif PlaceValidationResponse["ns1:type"] == "LUA_TSTRING":
                return jsonify({
                    "valid": False,
                    "reason": PlaceValidationResponse["ns1:value"]
                })
        logging.error(f"Failed to get response from OpenJob request to RCCService, status code: {str(OpenResponse.status_code)}, response: {OpenResponse.text}")
        return "Error", 500
    except Exception as e:
        logging.error(f"Error in AssetValidation2018: {e}")
        return "Error", 500

@app.route("/AssetValidation2020", methods=["POST"])
def AssetValidation2020():
    """
        Expected JSON Data:
        {
            "assetid": 1,
        }
    """
    try:
        ExecuteJSON = {
            "Mode": "Thumbnail",
            "Settings": {
                "Type": "PlaceValidation",
                "Arguments": [
                    f"{config.BaseURL}/asset/?id={request.json['assetid']}",
                    config.BaseURL
                ]
            }
        }

        InstanceController : RccController = GetNextAvailableRCCInstance( version = "2020" )
        ThumbnailJobId = str(uuid.uuid4())
        OpenResponse : requests.Response = InstanceController.SendBatchJobRequest(JobId=ThumbnailJobId, Expiration=40, Cores=1, ScriptName="Validation", Arguments=[], RunScript=json.dumps(ExecuteJSON), requestTimeout=45)
        if OpenResponse is None:
            logging.error("Failed to send OpenJob request")
            return "Error", 500
        if OpenResponse.status_code != 200:
            logging.error(f"Failed to send OpenJob request, status code: {str(OpenResponse.status_code)}, response: {OpenResponse.text}")
            return "Error", 500
        # Should only return one value which is either True as a bool or The reason as a string
        PlaceValidationResponse = xmltodict.parse(OpenResponse.text.strip())["SOAP-ENV:Envelope"]["SOAP-ENV:Body"]["ns1:BatchJobResponse"]["ns1:BatchJobResult"]
        if type(PlaceValidationResponse) == list:
            for ResponseItem in PlaceValidationResponse:
                if ResponseItem["ns1:type"] == "LUA_TBOOLEAN":
                    return jsonify({
                        "valid": ResponseItem["ns1:value"] == "true"
                    })
                elif ResponseItem["ns1:type"] == "LUA_TSTRING":
                    return jsonify({
                        "valid": False,
                        "reason": ResponseItem["ns1:value"]
                    })
        else:
            if PlaceValidationResponse["ns1:type"] == "LUA_TBOOLEAN":
                return jsonify({
                    "valid": PlaceValidationResponse["ns1:value"] == "true"
                })
            elif PlaceValidationResponse["ns1:type"] == "LUA_TSTRING":
                return jsonify({
                    "valid": False,
                    "reason": PlaceValidationResponse["ns1:value"]
                })
        logging.error(f"Failed to get response from OpenJob request to RCCService, status code: {str(OpenResponse.status_code)}, response: {OpenResponse.text}")
        return "Error", 500
    except Exception as e:
        logging.error(f"Error in AssetValidation2020: {e}")
        return "Error", 500
    
@app.route("/AssetValidation2021", methods=["POST"])
def AssetValidation2021():
    """
        Expected JSON Data:
        {
            "assetid": 1,
        }
    """
    try:
        ExecuteJSON = {
            "Mode": "Thumbnail",
            "Settings": {
                "Type": "PlaceValidation",
                "Arguments": [
                    f"{config.BaseURL}/asset/?id={request.json['assetid']}",
                    config.BaseURL
                ]
            }
        }

        InstanceController : RccController = GetNextAvailableRCCInstance( version = "2021" )
        ThumbnailJobId = str(uuid.uuid4())
        OpenResponse : requests.Response = InstanceController.SendBatchJobRequest(JobId=ThumbnailJobId, Expiration=40, Cores=1, ScriptName="Validation", Arguments=[], RunScript=json.dumps(ExecuteJSON), requestTimeout=45)
        if OpenResponse is None:
            logging.error("Failed to send OpenJob request")
            return "Error", 500
        if OpenResponse.status_code != 200:
            logging.error(f"Failed to send OpenJob request, status code: {str(OpenResponse.status_code)}, response: {OpenResponse.text}")
            return "Error", 500
        # Should only return one value which is either True as a bool or The reason as a string
        PlaceValidationResponse = xmltodict.parse(OpenResponse.text.strip())["SOAP-ENV:Envelope"]["SOAP-ENV:Body"]["ns1:BatchJobResponse"]["ns1:BatchJobResult"]
        if type(PlaceValidationResponse) == list:
            for ResponseItem in PlaceValidationResponse:
                if ResponseItem["ns1:type"] == "LUA_TBOOLEAN":
                    return jsonify({
                        "valid": ResponseItem["ns1:value"] == "true"
                    })
                elif ResponseItem["ns1:type"] == "LUA_TSTRING":
                    return jsonify({
                        "valid": False,
                        "reason": ResponseItem["ns1:value"]
                    })
        else:
            if PlaceValidationResponse["ns1:type"] == "LUA_TBOOLEAN":
                return jsonify({
                    "valid": PlaceValidationResponse["ns1:value"] == "true"
                })
            elif PlaceValidationResponse["ns1:type"] == "LUA_TSTRING":
                return jsonify({
                    "valid": False,
                    "reason": PlaceValidationResponse["ns1:value"]
                })
        logging.error(f"Failed to get response from OpenJob request to RCCService, status code: {str(OpenResponse.status_code)}, response: {OpenResponse.text}")
        return "Error", 500
    except Exception as e:
        logging.error(f"Error in AssetValidation2020: {e}")
        return "Error", 500

@app.route("/Thumbnail", methods=["POST"])
def Thumbnail():
    # Expected json data:
    # {
    #   "userid": 1, - needed for type 0 and 1
    #   "type": 1,
    #   "image_x": 512,
    #   "image_y": 512,
    #   "reqid": "uuid4"
    # }
    try:
        data = request.json
        data['starttime'] = time.time()
        if data['type'] in [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17]:
            thumbnailQueue.put(data)
            logging.info(f"Thumbnail request queued, id: {data['reqid']}, type: {data['type']}")
            return "OK", 200
        else:
            logging.error(f"Invalid thumbnail type: {data['type']}")
            return "Invalid thumbnail type", 400
    except Exception as e:
        logging.error(f"Error in Thumbnail: {e}")
        return "Error", 500
NextAvilablePort = config.RCCStartingPort


@app.route("/Game2014", methods=["POST"])
def Game2014():
    global NextAvilablePort
    """
        Expected JSON Data:
        {
            "placeid": 1,
            "creatorId": 1,
            "creatorType": 1
        }
    """
    try:
        GameOpenData = request.json
        ServerJobId = str(uuid.uuid4())
        ServerPort = NextAvilablePort
        NextAvilablePort += 1

        if NextAvilablePort > config.RCCEndingPort:
            NextAvilablePort = config.RCCStartingPort
        
        RCC_UDP_Proxy = None
        try:
            RCC_UDP_Proxy = UDPProxy(
                UDPProxyPort=ServerPort,
                UDPProxyTargetHost="127.0.0.1",
                UDPProxyTargetPort=ServerPort + config.PortOffset
            )
            RCC_UDP_Proxy.StartUDPProxy()
        except Exception as e:
            logging.error(f"Error creating UDPProxy: {e}")
            return "Error", 500

        try:
            InstanceController : ClientController = ClientController(
                ExecutablePath = config.Client2014Path,
                JoinscriptUrl = f"{config.BaseURL}/game/gameserver2014.lua?placeId={GameOpenData['placeid']}&networkPort={ServerPort + config.PortOffset}&creatorId={GameOpenData['creatorId']}&creatorType={GameOpenData['creatorType']}&jobId={ServerJobId}",
                ExpectedPort = ServerPort + config.PortOffset,
                StartTimeout = 40
            )
        except Exception as e:
            logging.error("Failed to start 2014Client Controller in Game2014, error: " + str(e))
            RCC_UDP_Proxy.StopUDPProxy()
            return "Error", 500
        
        RunningJobs[ServerJobId] = InstanceController
        if RCC_UDP_Proxy is not None:
            InstanceController.BindUDPProxy(RCC_UDP_Proxy)

        logging.info(f"Game server opened, jobid: {ServerJobId}, Port Forwarded: {ServerPort}, Actual Port: {ServerPort + config.PortOffset}")
        return jsonify({
            "jobid": ServerJobId,
            "port": ServerPort
        })
    
    except Exception as e:
        logging.error(f"Error in Game2014: {e}")
        return "Error", 500

@app.route("/Game", methods=["POST"])
def Game():
    global RunningJobs
    global NextAvilablePort
    # Expected json data:
    # {
    #  "placeid": 1,
    #  "creatorId": 1,
    #  "creatorType": 1,
    #  "useNewLoadFile": true
    #  "loadfile_location": "https://www.syntax.eco/game/gameserver2016.lua"
    # }
    try:
        GameOpenData = request.json
        if not GameOpenData['useNewLoadFile']:
            with open("./Scripts/Gameserver.lua", "r") as f:
                script = f.read()
        else:
            script = f"loadfile(\"{GameOpenData['loadfile_location']}\")(...)"
        
        ServerJobId = str(uuid.uuid4())
        ServerPort = NextAvilablePort
        NextAvilablePort += 1
        if NextAvilablePort > config.RCCEndingPort:
            NextAvilablePort = config.RCCStartingPort

        RCC_UDP_Proxy = None
        try:
            RCC_UDP_Proxy = UDPProxy(
                UDPProxyPort=ServerPort,
                UDPProxyTargetHost="127.0.0.1",
                UDPProxyTargetPort=ServerPort + config.PortOffset
            )
            RCC_UDP_Proxy.StartUDPProxy()
        except Exception as e:
            logging.error(f"Error creating UDPProxy: {e}")
            return "Error", 500

        InstanceController : RccController = GetNextAvailableRCCInstance()
        OpenJobResponse : requests.Response = InstanceController.SendOpenJobRequest(
            JobId=ServerJobId,
            Expiration=60*60*24, # 24 hours
            Cores=2,
            ScriptName="GameServer",
            RunScript=script,
            Arguments=[
                GameOpenData['placeid'],
                (ServerPort + config.PortOffset) if RCC_UDP_Proxy is not None else ServerPort,
                config.BaseURL,
                ReadAccessKey(),
                GameOpenData['creatorId'],
                GameOpenData['creatorType'],
                GameOpenData['SpecialAccessToken'],
                GameOpenData['universeid'] if 'universeid' in GameOpenData else GameOpenData['placeid']
            ]
        )
        if OpenJobResponse.status_code != 200:
            logging.error(f"Error sending OpenJob request to RCCService, status code: {OpenJobResponse.status_code}, response: {OpenJobResponse.text}")
            InstanceController.KillRCC()
            if RCC_UDP_Proxy is not None:
                RCC_UDP_Proxy.StopUDPProxy()
            return "Error", 500
        RunningJobs[ServerJobId] = InstanceController
        if RCC_UDP_Proxy is not None:
            InstanceController.BindUDPProxy(RCC_UDP_Proxy)
        logging.info(f"Game server opened, jobid: {ServerJobId}, Port Forwarded: {ServerPort}, Actual Port: {ServerPort + config.PortOffset}")
        return jsonify({
            "jobid": ServerJobId,
            "port": ServerPort
        })
    except Exception as e:
        logging.error(f"Error in Game: {e}")
        return "Error", 500

@app.route("/Game2018", methods=["POST"])
def Game2018():
    global RunningJobs
    global NextAvilablePort
    """
        Expected JSON Data:
        {
            "placeid": 1,
            "creatorId": 1,
            "creatorType": "User",
            "jobid": "uuid4",
            "apikey": "apikey",
            "maxplayers": 10,
            "address": "127.0.0.1"
        }
    """
    try:
        GameOpenData = request.json # We trust the game server to send us the correct data :)
        ServerPort = NextAvilablePort
        NextAvilablePort += 1
        if NextAvilablePort > config.RCCEndingPort:
            NextAvilablePort = config.RCCStartingPort
        RCC_UDP_Proxy = None
        try:
            RCC_UDP_Proxy = UDPProxy(
                UDPProxyPort=ServerPort,
                UDPProxyTargetHost="127.0.0.1",
                UDPProxyTargetPort=ServerPort + config.PortOffset
            )
            RCC_UDP_Proxy.StartUDPProxy()
        except Exception as e:
            logging.error(f"Error creating UDPProxy: {e}")
            return "Error", 500
        
        InstanceController : RccController = GetNextAvailableRCCInstance( version = "2018" )
        RCCFormatter = RCCSOAPMessages()
        GameOpenJSON = RCCFormatter.FormatGameOpenJSON(
            PlaceId = GameOpenData['placeid'],
            CreatorId = GameOpenData['creatorId'],
            CreatorType = GameOpenData['creatorType'],
            JobId = GameOpenData['jobid'],
            ApiKey = GameOpenData['apikey'],
            MaxPlayers = GameOpenData['maxplayers'],
            PortNumber = (ServerPort + config.PortOffset) if RCC_UDP_Proxy is not None else ServerPort,
            MachineAddress = "127.0.0.1" if RCC_UDP_Proxy is not None else GameOpenData['address'],
            UniverseId = GameOpenData['universeid'] if 'universeid' in GameOpenData else GameOpenData['placeid']
        )
        OpenJobResponse : requests.Response = InstanceController.SendOpenJobRequest(
            JobId=GameOpenData['jobid'],
            Expiration=60*60*24, # 24 hours
            Cores=1,
            ScriptName="GameServer",
            RunScript=GameOpenJSON,
            Arguments=[]
        )
        if OpenJobResponse.status_code != 200:
            logging.error(f"Error sending OpenJob request to RCCService, status code: {OpenJobResponse.status_code}, response: {OpenJobResponse.text}")
            InstanceController.KillRCC()
            if RCC_UDP_Proxy is not None:
                RCC_UDP_Proxy.StopUDPProxy()
            return "Error", 500
        RunningJobs[GameOpenData['jobid']] = InstanceController
        if RCC_UDP_Proxy is not None:
            InstanceController.BindUDPProxy(RCC_UDP_Proxy)
        logging.info(f"2018 Game server opened, jobid: {GameOpenData['jobid']}, Port Forwarded: {ServerPort}, Actual Port: {ServerPort + config.PortOffset}")
        return jsonify({
            "jobid": GameOpenData['jobid'],
            "port": ServerPort
        })
    except Exception as e:
        logging.error(f"Error in Game2018: {e}")
        return "Error", 500

@app.route("/Game2020", methods=["POST"])
def Game2020():
    global RunningJobs
    global NextAvilablePort
    """
        Expected JSON Data:
        {
            "placeid": 1,
            "creatorId": 1,
            "creatorType": "User",
            "jobid": "uuid4",
            "apikey": "apikey",
            "maxplayers": 10,
            "address": "127.0.0.1"
        }
    """
    try:
        GameOpenData = request.json # We trust the game server to send us the correct data :)
        ServerPort = NextAvilablePort
        NextAvilablePort += 1
        if NextAvilablePort > config.RCCEndingPort:
            NextAvilablePort = config.RCCStartingPort
        RCC_UDP_Proxy = None
        try:
            RCC_UDP_Proxy = UDPProxy(
                UDPProxyPort=ServerPort,
                UDPProxyTargetHost="127.0.0.1",
                UDPProxyTargetPort=ServerPort + config.PortOffset
            )
            RCC_UDP_Proxy.StartUDPProxy()
        except Exception as e:
            logging.error(f"Error creating UDPProxy: {e}")
            return "Error", 500
        
        InstanceController : RccController = GetNextAvailableRCCInstance( version = "2020" )
        RCCFormatter = RCCSOAPMessages()
        GameOpenJSON = RCCFormatter.FormatGameOpenJSON(
            PlaceId = GameOpenData['placeid'],
            CreatorId = GameOpenData['creatorId'],
            CreatorType = GameOpenData['creatorType'],
            JobId = GameOpenData['jobid'],
            ApiKey = GameOpenData['apikey'],
            MaxPlayers = GameOpenData['maxplayers'],
            PortNumber = (ServerPort + config.PortOffset) if RCC_UDP_Proxy is not None else ServerPort,
            MachineAddress = "127.0.0.1" if RCC_UDP_Proxy is not None else GameOpenData['address'],
            UniverseId = GameOpenData['universeid'] if 'universeid' in GameOpenData else GameOpenData['placeid']
        )
        OpenJobResponse : requests.Response = InstanceController.SendOpenJobRequest(
            JobId=GameOpenData['jobid'],
            Expiration=60*60*24, # 24 hours
            Cores=1,
            ScriptName="GameServer",
            RunScript=GameOpenJSON,
            Arguments=[]
        )
        if OpenJobResponse.status_code != 200:
            logging.error(f"Error sending OpenJob request to RCCService, status code: {OpenJobResponse.status_code}, response: {OpenJobResponse.text}")
            InstanceController.KillRCC()
            if RCC_UDP_Proxy is not None:
                RCC_UDP_Proxy.StopUDPProxy()
            return "Error", 500
        RunningJobs[GameOpenData['jobid']] = InstanceController
        if RCC_UDP_Proxy is not None:
            InstanceController.BindUDPProxy(RCC_UDP_Proxy)
        logging.info(f"2020 Game server opened, jobid: {GameOpenData['jobid']}, Port Forwarded: {ServerPort}, Actual Port: {ServerPort + config.PortOffset}")
        return jsonify({
            "jobid": GameOpenData['jobid'],
            "port": ServerPort
        })
    except Exception as e:
        logging.error(f"Error in Game2020: {e}")
        return "Error", 500

@app.route("/Game2021", methods=["POST"])
def Game2021():
    global RunningJobs
    global NextAvilablePort
    """
        Expected JSON Data:
        {
            "placeid": 1,
            "creatorId": 1,
            "creatorType": "User",
            "jobid": "uuid4",
            "apikey": "apikey",
            "maxplayers": 10,
            "address": "127.0.0.1"
        }
    """
    try:
        GameOpenData = request.json # We trust the game server to send us the correct data :)
        ServerPort = NextAvilablePort
        NextAvilablePort += 1
        if NextAvilablePort > config.RCCEndingPort:
            NextAvilablePort = config.RCCStartingPort
        RCC_UDP_Proxy = None
        try:
            RCC_UDP_Proxy = UDPProxy(
                UDPProxyPort=ServerPort,
                UDPProxyTargetHost="127.0.0.1",
                UDPProxyTargetPort=ServerPort + config.PortOffset
            )
            RCC_UDP_Proxy.StartUDPProxy()
        except Exception as e:
            logging.error(f"Error creating UDPProxy: {e}")
            return "Error", 500
        
        InstanceController : RccController = GetNextAvailableRCCInstance( version = "2021" )
        RCCFormatter = RCCSOAPMessages()
        GameOpenJSON = RCCFormatter.FormatGameOpenJSON(
            PlaceId = GameOpenData['placeid'],
            CreatorId = GameOpenData['creatorId'],
            CreatorType = GameOpenData['creatorType'],
            JobId = GameOpenData['jobid'],
            ApiKey = GameOpenData['apikey'],
            MaxPlayers = GameOpenData['maxplayers'],
            PortNumber = (ServerPort + config.PortOffset) if RCC_UDP_Proxy is not None else ServerPort,
            MachineAddress = "127.0.0.1" if RCC_UDP_Proxy is not None else GameOpenData['address'],
            UniverseId = GameOpenData['universeid'] if 'universeid' in GameOpenData else GameOpenData['placeid']
        )
        OpenJobResponse : requests.Response = InstanceController.SendOpenJobRequest(
            JobId=GameOpenData['jobid'],
            Expiration=60*60*24, # 24 hours
            Cores=1,
            ScriptName="GameServer",
            RunScript=GameOpenJSON,
            Arguments=[]
        )
        if OpenJobResponse.status_code != 200:
            logging.error(f"Error sending OpenJob request to RCCService, status code: {OpenJobResponse.status_code}, response: {OpenJobResponse.text}")
            InstanceController.KillRCC()
            if RCC_UDP_Proxy is not None:
                RCC_UDP_Proxy.StopUDPProxy()
            return "Error", 500
        RunningJobs[GameOpenData['jobid']] = InstanceController
        if RCC_UDP_Proxy is not None:
            InstanceController.BindUDPProxy(RCC_UDP_Proxy)
        logging.info(f"2021 Game server opened, jobid: {GameOpenData['jobid']}, Port Forwarded: {ServerPort}, Actual Port: {ServerPort + config.PortOffset}")
        return jsonify({
            "jobid": GameOpenData['jobid'],
            "port": ServerPort
        })
    except Exception as e:
        logging.error(f"Error in Game2021: {e}")
        return "Error", 500

@app.route("/Execute", methods=["POST"])
def ExecuteScript():
    global RunningJobs
    try:
        data = request.json
        script = data['script']
        arguments = data['arguments'] if 'arguments' in data else []
        scriptname = data['scriptname'] if 'scriptname' in data else "RunScript"
        jobid = data['jobid'] if 'jobid' in data else None
        if jobid is None:
            return "Error", 400
        if jobid not in RunningJobs:
            return "Error", 400
        InstanceController : RccController = RunningJobs[jobid]
        if InstanceController.PingRCC() == False:
            del RunningJobs[jobid]
            return "Error", 400
        ExecuteScriptResponse : requests.Response = InstanceController.SendExecuteScriptRequest(jobid, scriptname, script, arguments)
        if ExecuteScriptResponse.status_code != 200:
            logging.error(f"Error sending ExecuteScript request to RCCService, status code: {ExecuteScriptResponse.status_code}, response: {ExecuteScriptResponse.text}")
            return "Error", 500
        return "OK", 200

    except Exception as e:
        logging.error(f"Error in Execute: {e}")
        return "Error", 500

@app.route("/CloseJob", methods=["POST"])
def CloseJob():
    try:
        global RunningJobs

        data = request.json
        jobid = data['jobid']
        
        if jobid not in RunningJobs:
            try:
                del RunningJobs[jobid]
            except:
                pass
            logging.info(f"Requested to close a job that is not running, jobid: {jobid}")
            return "OK", 200
        InstanceController : RccController | ClientController = RunningJobs[jobid]
        if type(InstanceController) == ClientController:
            if InstanceController.Process.poll() is None:
                InstanceController.KillRCC()
            del RunningJobs[jobid]
            return "OK", 200
        
        if InstanceController.PingRCC() == False:
            del RunningJobs[jobid]
            return "OK", 200
        
        CloseJobResposne : requests.Response = InstanceController.SendCloseJobRequest(jobid)
        if CloseJobResposne is None:
            # this means that the RCC is already dead
            del RunningJobs[jobid]
            return "OK", 200

        if CloseJobResposne.status_code != 200:
            logging.error(f"Error sending CloseJob request to RCCService, status code: {CloseJobResposne.status_code}, response: {CloseJobResposne.text}")
            return "Error", 500
        del RunningJobs[jobid]
        InstanceController.KillRCC()
        logging.info(f"Game server closed, jobid: {jobid}")
        return "OK", 200

    except Exception as e:
        logging.error(f"Error in CloseJob: {e}")
        return "Error", 500

@app.route("/ResetAccessKeyAndRestart", methods=["POST"])
def ResetAccessKeyAndRestart():
    try:
        global RunningJobs
        global AvailableJobs
        global AvailableJobs2018
        global AvailableJobs2020
        global AvailableJobs2021

        PayloadData = request.json
        if "NewAccessKey" not in PayloadData:
            return "Error", 400
        
        RunningJobs = {}
        AvailableJobs = []
        AvailableJobs2018 = []
        AvailableJobs2020 = []
        AvailableJobs2021 = []

        logging.info(f"ResetAccessKeyAndRestart : Command received, killing all instances and switching to : {PayloadData['NewAccessKey']}")
        WriteAccessKey( PayloadData["NewAccessKey"] )

        try:
            os.system("taskkill /IM RCCService.exe /T /F")
            os.system("taskkill /IM SyntaxPlayerBeta.exe /T /F")
        except:
            pass

        threading.Thread(target=RefillAvailableJobs).start()

        return "OK", 200
    except Exception as e:
        logging.error(f"Error in ResetAccessKeyAndRestart: {e}")
        return "Error", 500

def CollectDeadProcess():
    try:
        running_servers : list[psutil.Process] = []
        processes = psutil.process_iter()
        for process in processes:
            if "RCCService" in process.name() or "SyntaxPlayerBeta" in process.name():
                running_servers.append(process)
        
        for active_server in running_servers:
            if active_server.memory_info().rss / 1024 ** 2 > 3000:
                active_server.kill()
                logging.info(f"Killed process {active_server.pid} because it was using too much memory")
                continue
            if active_server.status() in [psutil.STATUS_DEAD, psutil.STATUS_STOPPED, psutil.STATUS_ZOMBIE, psutil.STATUS_IDLE]:
                active_server.kill()
                logging.info(f"Killed process {active_server.pid} because it was in {str(active_server.status())} state")
                continue

            if "SyntaxPlayerBeta" in active_server.name():
                if active_server.cpu_percent() > 90:
                    active_server.kill()
                    logging.info(f"Killed process {active_server.pid} because it was using too much cpu")
                    continue
                if active_server.create_time() < time.time() - 60 * 60 * 24:
                    active_server.kill()
                    logging.info(f"Killed process {active_server.pid} because it was running for too long")
                    continue
        
        def EnumWindowsCallback( hwnd, lParam ):
            if win32gui.GetWindowText(hwnd) == "ROBLOX Crash":
                win32gui.PostMessage(hwnd, win32con.WM_CLOSE, 0, 0)
            return True
        win32gui.EnumWindows(EnumWindowsCallback, 0)

    except Exception as e:
        logging.error(f"Error in CollectDeadProcess: {e}")

def RunCollectDeadProcessWorker():
    while True:
        try:
            CollectDeadProcess()
        except Exception as e:
            logging.error(f"Error in CollectDeadProcessWorker: {e}")
        time.sleep(25)

@app.route("/stats", methods=["GET"])
def Stats():
    global RunningJobs
    RCCMemoryUsage = 0
    while True:
        try:
            for jobid in RunningJobs:
                InstanceController : RccController | ClientController = RunningJobs[jobid]
                if type(InstanceController) == ClientController:
                    if InstanceController.Process.poll() is not None:
                        del RunningJobs[jobid]
                        continue
                    RCCMemoryUsage += psutil.Process(InstanceController.Process.pid).memory_info().rss / 1024 ** 2

                    def EnumWindowsCallback( hwnd, lParam ):
                        if win32gui.GetWindowText(hwnd) == "ROBLOX":
                            win32gui.ShowWindow(hwnd, win32con.SW_MINIMIZE)
                        return True
                    win32gui.EnumWindows(EnumWindowsCallback, 0)
                else:
                    if InstanceController.PingRCC() == False:
                        del RunningJobs[jobid]
                        continue
                    RCCMemoryUsage += psutil.Process(InstanceController.RCCProcess.pid).memory_info().rss / 1024 ** 2
            break
        except Exception as e:
            pass

    ListOfRunningJobs = []
    for jobid in RunningJobs:
        ListOfRunningJobs.append(jobid)

    return jsonify({
        "RCCOnline": True, #isRCCOnline(), This was before we created a new rcc instance for each job but we leave it here for now
        "RCCMemoryUsage": RCCMemoryUsage,
        "ThumbnailQueueSize": thumbnailQueue.qsize(),
        "RunningJobs": ListOfRunningJobs
    })


if __name__ == "__main__":
    try:
        RCCReturnAuth = str(uuid.uuid4())
        logging.info(f"Read Access Key: {ReadAccessKey()}")
        logging.info("RCCReturnAuth: " + RCCReturnAuth)
        for i in range(config.ThumbnailWorkerCount):
            logging.info(f"Starting thumbnailQueueWorker {str(i)}")
            thumbnailQueueWorkerThread = threading.Thread(target=thumbnailQueueWorker, args=(i, ))
            time.sleep(0.1)
            thumbnailQueueWorkerThread.start()
        threading.Thread(target=RefillAvailableJobs).start()
        threading.Thread(target=RunCollectDeadProcessWorker).start()
        app.run(
            host="0.0.0.0",
            port=Config.CommPort,
            debug=False
        )
        StopThreads = True
    except KeyboardInterrupt:
        StopThreads = True