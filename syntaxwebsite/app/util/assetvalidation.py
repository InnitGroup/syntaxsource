import hashlib
from PIL import Image
from app.routes.asset import CreateFakeAsset
from app.routes.thumbnailer import ValidatePlaceFileRequest
from app.enums.PlaceYear import PlaceYear
from app.util import s3helper
import uuid
import time
import json
import os
import logging
import eyed3
import tempfile
import ffmpeg

# TODO: Make this less shit

def ValidateClothingImage( file, verifyResolution = True, validateFileSize = True, returnImage = False ):
    try:
        file.seek(0, os.SEEK_END)
        FileSize = file.tell()
        if FileSize > 1024 * 1024 and validateFileSize:
            raise Exception("File is larger than 1MB")

        ImageObj = Image.open(file)
        ImageObj.verify()
        
        if ImageObj.format != "PNG":
            raise Exception("File is not a PNG file")
        
        if ImageObj.size != (585, 559) and verifyResolution:
            raise Exception("File is not 585 x 559")
        
        if returnImage:
            file.seek(0, os.SEEK_END)

            ImageObj = Image.open(file).convert("RGBA")
            ImageData = list(ImageObj.getdata())
            SanitizedImage = Image.new(ImageObj.mode, ImageObj.size)
            SanitizedImage.putdata(ImageData)

            return SanitizedImage
        
    except Exception as e:
        return False
    return True

def ValidatePlaceFile( file, keepFileWhenInvalid = False, TestPlaceYear : PlaceYear = PlaceYear.Eighteen, bypassCache : bool = False ):
    try:
        from app.extensions import redis_controller
        file.seek(0, os.SEEK_END)
        FileSize = file.tell()
        if FileSize > 1024 * 1024 * 30:
            raise Exception("File is larger than 30MB")
        file.seek(0)
        FileContents = file.read()
        FileHash = hashlib.sha512(FileContents).hexdigest()

        if not bypassCache:
            validationResults : int | None = redis_controller.get(f"ValidatePlaceFile:{FileHash}:{TestPlaceYear.value}")
            if validationResults is not None:
                return validationResults == 1

        s3helper.UploadBytesToS3(FileContents, FileHash)
        TemporaryAssetId = CreateFakeAsset(AssetName = "AssetValidationService", Expiration = 60 * 10, AssetFileHash = FileHash)
        PlaceValidationReqUUID = str(uuid.uuid4())
        
        ValidatePlaceFileRequest( TemporaryAssetId, PlaceValidationReqUUID, TestPlaceYear)
        logging.info(f"Sent validation request for '{FileHash}' with UUID {PlaceValidationReqUUID}")
        StartTime = time.time()
        ResponseInfo = None
        while True:
            if time.time() - StartTime > 45:
                raise Exception("Timed out while waiting for a response from AssetValidation Service")
            ResponseInfo = redis_controller.get(f"ValidatePlaceFileRequest:{PlaceValidationReqUUID}")
            if ResponseInfo is None:
                time.sleep(0.2)
                continue
            else:
                break
        if ResponseInfo is not None:
            ResponseInfo = json.loads(ResponseInfo)
            if ResponseInfo["valid"]:
                redis_controller.set(f"ValidatePlaceFile:{FileHash}:{TestPlaceYear.value}", 1, 60 * 60 * 24 * 2)
                return True
            else:
                redis_controller.set(f"ValidatePlaceFile:{FileHash}:{TestPlaceYear.value}", 0, 60 * 60 * 24 * 2)
                raise Exception(ResponseInfo["error"])
    except Exception as e:
        if not keepFileWhenInvalid:
            try:
                s3helper.DeleteFileFromS3(FileHash)
            except:
                pass
        return str(e)
    return True

def ValidateMP3File( file ) -> int | None:
    """
        Validates an MP3 file and returns duration in seconds
    """
    TemporaryFile = tempfile.NamedTemporaryFile(suffix=".mp3", delete=True)
    file.seek(0)
    TemporaryFile.write(file.read())
    try:
        AudioFile = eyed3.load(TemporaryFile.name)
        if AudioFile is None:
            return None
        TemporaryFile.close()
        return AudioFile.info.time_secs
    except Exception as e:
        logging.error(f"Failed to validate MP3 file: {e}")
        return None

def ValidateMP3AndConvertToOGG( file ) -> (bytes, int):
    """
        Validates given file is a MP3 File and then converts it into the OGG format and returns the bytes and length of the sound in seconds
    """
    TemporaryFile = tempfile.NamedTemporaryFile(suffix=".mp3", delete=True)
    OutputTemporaryFile = tempfile.NamedTemporaryFile(suffix=".ogg", delete=True)
    try:
        file.seek(0)
        TemporaryFile.write(file.read())

        AudioFile = eyed3.load(TemporaryFile.name)
        if AudioFile is None:
            TemporaryFile.close()
            raise Exception("Failed to load MP3 file")
        FFmpegStream = ffmpeg.input(TemporaryFile.name, vn=None)
        FFmpegStream = ffmpeg.output(FFmpegStream, OutputTemporaryFile.name, acodec="libvorbis", f="ogg")
        ffmpeg.run(FFmpegStream, overwrite_output = True, quiet = True, capture_stdout = False, capture_stderr = False)
        OutputTemporaryFile.seek(0)
        OutputFileBytes = OutputTemporaryFile.read()

        ProbeResult = ffmpeg.probe(OutputTemporaryFile.name, select_streams="a")
        AudioDuration = float(ProbeResult["streams"][0]["duration"])

        OutputTemporaryFile.close()
        TemporaryFile.close()
        return OutputFileBytes, AudioDuration
    except Exception as e:
        logging.error(f"Failed to validate MP3 file: {e}")

        TemporaryFile.close()
        OutputTemporaryFile.close()
        raise e