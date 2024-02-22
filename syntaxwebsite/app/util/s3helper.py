import boto3
import hashlib
import os
import logging
from app.extensions import redis_controller
from config import Config

Config = Config()

def getS3Client():
    """
    Returns a boto3 S3 client object.
    """
    
    return boto3.client(
        "s3",
        aws_access_key_id = Config.AWS_ACCESS_KEY,
        aws_secret_access_key = Config.AWS_SECRET_KEY,
        region_name = Config.AWS_REGION_NAME
    )

def UploadBytesToS3( fileContent : bytes, nameOverwrite : str | None = None, bucketOverwrite : str | None = Config.AWS_S3_BUCKET_NAME, contentType : str = "application/octet-stream", bypassExistCheck : bool = False) -> str:
    """
        Uploads a file to S3, returning the URL of the file.

        :param fileContent: The bytes of the file to upload
        :param nameOverwrite: The name of the file to overwrite
        :param bucketOverwrite: The bucket to overwrite
        :param contentType: The content type of the file
        :param bypassExistCheck: Whether to bypass the redis cache or not

        :returns: str (The URL of the file)
    """
    
    if nameOverwrite is None:
        nameOverwrite = hashlib.sha512( fileContent ).hexdigest()
    if Config.USE_LOCAL_STORAGE:
        if not os.path.exists(Config.AWS_S3_DOWNLOAD_CACHE_DIR + "/" + nameOverwrite):
            with open(Config.AWS_S3_DOWNLOAD_CACHE_DIR + "/" + nameOverwrite, "wb") as f:
                f.write(fileContent)
        return f"{Config.CDN_URL}/{nameOverwrite}"

    if not bypassExistCheck:
        if redis_controller.exists( f"DoesKeyExist:{bucketOverwrite}:{nameOverwrite}" ):
            return f"{Config.CDN_URL}/{nameOverwrite}"
    
    s3Client = getS3Client()

    s3Client.put_object(
        Body = fileContent,
        Bucket = bucketOverwrite,
        Key = nameOverwrite,
        ContentType = contentType
    )
    redis_controller.set( f"DoesKeyExist:{bucketOverwrite}:{nameOverwrite}", "1", 60 * 60 * 24 * 7 )
    return f"{Config.CDN_URL}/{nameOverwrite}"

def UploadFileToS3( filePath : str, nameOverwrite : str | None = None, bucketOverwrite : str | None = Config.AWS_S3_BUCKET_NAME ) -> str:
    """
        Uploads a file to S3, returning the URL of the file.

        :param filePath: The path of the file to upload
        :param nameOverwrite: The name of the file to overwrite
        :param bucketOverwrite: The bucket to overwrite

        :returns: str (The URL of the file)
    """

    if nameOverwrite is None:
        nameOverwrite = hashlib.sha512( open( filePath, "rb" ).read() ).hexdigest()

    if Config.USE_LOCAL_STORAGE:
        FileData = open(filePath, "rb").read()
        return UploadBytesToS3(FileData, nameOverwrite, bucketOverwrite, bypassExistCheck=True)
    
    s3Client = getS3Client()

    s3Client.upload_file(
        filePath,
        bucketOverwrite,
        nameOverwrite
    )
    redis_controller.set( f"DoesKeyExist:{bucketOverwrite}:{nameOverwrite}", "1", 60 * 60 * 24 * 7 )
    return f"{Config.CDN_URL}/{nameOverwrite}"

def DeleteFileFromS3( fileName : str, bucketOverwrite : str | None = Config.AWS_S3_BUCKET_NAME ) -> bool:
    """
        Deletes a file from S3.

        :param fileName: The name of the file to delete
        :param bucketOverwrite: The bucket to overwrite

        :returns: bool (Whether the file was deleted or not)
    """
    
    if Config.USE_LOCAL_STORAGE:
        if os.path.exists(f"{Config.AWS_S3_DOWNLOAD_CACHE_DIR}/{fileName}"):
            os.remove(f"{Config.AWS_S3_DOWNLOAD_CACHE_DIR}/{fileName}")
        return True

    s3Client = getS3Client()

    s3Client.delete_object(
        Bucket = bucketOverwrite,
        Key = fileName
    )
    redis_controller.delete( f"DoesKeyExist:{bucketOverwrite}:{fileName}" )
    return True

def GetFileFromS3( fileName : str, bucketOverwrite : str | None = Config.AWS_S3_BUCKET_NAME, skipDownloadCache : bool = False ) -> bytes | None:
    """
        Gets a file from S3.

        :param fileName: The name of the file to get
        :param bucketOverwrite: The bucket to overwrite
        :param skipDownloadCache: Whether to skip the download cache or not

        :returns: bytes (The bytes of the file)
    """

    if not skipDownloadCache or Config.USE_LOCAL_STORAGE:
        if redis_controller.exists(f"DownloadCache:{bucketOverwrite}:{fileName}") and os.path.exists(f"{Config.AWS_S3_DOWNLOAD_CACHE_DIR}/{fileName}"):
            return open(f"{Config.AWS_S3_DOWNLOAD_CACHE_DIR}/{fileName}", "rb").read()
        if Config.USE_LOCAL_STORAGE:
            return None

    s3Client = getS3Client()

    try:
        FileBytes = s3Client.get_object(
            Bucket = bucketOverwrite,
            Key = fileName
        )['Body'].read()
    except Exception as e: 
        logging.error(f"S3Helper.GetFileFromS3 / Exception raised when fetching file from S3 Bucket [ {bucketOverwrite} ] with name [ {fileName} ] / {e}]")
        return None

    if not os.path.exists(Config.AWS_S3_DOWNLOAD_CACHE_DIR):
        os.mkdir(Config.AWS_S3_DOWNLOAD_CACHE_DIR)
    with open(f"{Config.AWS_S3_DOWNLOAD_CACHE_DIR}/{fileName}", "wb") as f:
        f.write(FileBytes)
    redis_controller.set(f"DownloadCache:{bucketOverwrite}:{fileName}", "1", Config.AWS_S3_CACHE_LIFETIME)

    return FileBytes

def DoesKeyExist( key : str, bucketOverwrite : str | None = Config.AWS_S3_BUCKET_NAME, bypassCache : bool = False ) -> bool:
    """
        Returns whether or not a key exists in S3.

        :param key: The key to check
        :param bucketOverwrite: The bucket to overwrite
        :param bypassCache: Whether to bypass the redis cache or not

        :returns: bool (Whether the key exists or not)
    """
    
    if Config.USE_LOCAL_STORAGE:
        return os.path.exists(f"{Config.AWS_S3_DOWNLOAD_CACHE_DIR}/{key}")

    if not bypassCache:
        if redis_controller.exists( f"DoesKeyExist:{bucketOverwrite}:{key}" ):
            return True
    s3Client = getS3Client()

    try:
        s3Client.head_object(
            Bucket = bucketOverwrite,
            Key = key
        )
    except:
        redis_controller.delete( f"DoesKeyExist:{bucketOverwrite}:{key}" )
        return False
    
    redis_controller.set( f"DoesKeyExist:{bucketOverwrite}:{key}", "1", 60 * 60 * 24 * 7 )
    return True