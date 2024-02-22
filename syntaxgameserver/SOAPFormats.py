import xmltodict
import json

class RCCSOAPMessages():
    GetAllJobsMsg = """<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:rob="http://roblox.com/">
   <soapenv:Header/>
   <soapenv:Body>
      <rob:GetAllJobs/>
   </soapenv:Body>
</soapenv:Envelope>"""

    OpenJobMsg = """<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:rob="http://roblox.com/">
   <soapenv:Header/>
   <soapenv:Body>
      <rob:OpenJob>
         <rob:job>
            <rob:id>{JobId}</rob:id>
            <rob:expirationInSeconds>{JobExpiration}</rob:expirationInSeconds>
            <rob:cores>{JobCores}</rob:cores>
         </rob:job>
         <rob:script>
            <rob:name>{ScriptName}</rob:name>
            <rob:script><![CDATA[
{RunScript}
            ]]></rob:script>
            <rob:arguments>
                {Arguments}
            </rob:arguments>
         </rob:script>
      </rob:OpenJob>
   </soapenv:Body>
</soapenv:Envelope>"""

    BatchJobMsg = """<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:rob="http://roblox.com/">
   <soapenv:Header/>
   <soapenv:Body>
      <rob:BatchJob>
         <rob:job>
            <rob:id>{JobId}</rob:id>
            <rob:expirationInSeconds>{JobExpiration}</rob:expirationInSeconds>
            <rob:cores>{JobCores}</rob:cores>
         </rob:job>
         <rob:script>
            <rob:name>{ScriptName}</rob:name>
            <rob:script><![CDATA[
{RunScript}
            ]]></rob:script>
            <rob:arguments>
                {Arguments}
            </rob:arguments>
         </rob:script>
      </rob:BatchJob>
   </soapenv:Body>
</soapenv:Envelope>"""

    CloseJobMsg = """<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:rob="http://roblox.com/">
   <soapenv:Header/>
   <soapenv:Body>
      <rob:CloseJob>
         <rob:jobID>{JobId}</rob:jobID>
      </rob:CloseJob>
   </soapenv:Body>
</soapenv:Envelope>"""

    ExecuteScriptMsg = """<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:rob="http://roblox.com/">
   <soapenv:Header/>
   <soapenv:Body>
      <rob:Execute>
         <rob:jobID>{JobId}</rob:jobID>
         <rob:script>
            <rob:name>{ScriptName}</rob:name>
            <rob:script>{Script}</rob:script>
            <rob:arguments>
               {Arguments}
            </rob:arguments>
         </rob:script>
      </rob:Execute>
   </soapenv:Body>
</soapenv:Envelope>"""

    def ParseXMLResponse(self, response : str):
        return xmltodict.parse(response.strip())

    def GenerateArguments(self, Arguments) -> str:
        """
            Converts the list of arguments into XML to be passed into the script
        """
        ArgumentsText = ""
        for arg in Arguments:
            # Types
            # LUA_TNIL
            # LUA_TBOOLEAN
            # LUA_TNUMBER
            # LUA_TSTRING
            # LUA_TTABLE
            # We need to convert the arg
            if type(arg) == bool:
                argType = "LUA_TBOOLEAN"
                argValue = str(arg).lower()
            elif type(arg) == int or type(arg) == float:
                argType = "LUA_TNUMBER"
                argValue = str(arg)
            elif type(arg) == str:
                argType = "LUA_TSTRING"
                argValue = arg
            ArgumentsText += f"""<rob:LuaValue>
                    <rob:type>{argType}</rob:type>
                    <rob:value>{argValue}</rob:value>
                </rob:LuaValue>"""
        return ArgumentsText

    def FormatOpenJobMessage( self, JobId : str, Expiration : int = 20, Cores : int = 1, ScriptName : str = "RunScript", RunScript : str = "", Arguments = []) -> str:
        """
            Formats the OpenJobMsg with the given parameters
        """
        ParsedArguments : str = self.GenerateArguments(Arguments)
        return self.OpenJobMsg.format(
            JobId = JobId,
            JobExpiration = str(Expiration),
            JobCores = str(Cores),
            ScriptName = ScriptName,
            RunScript = RunScript,
            Arguments = ParsedArguments
        )
    
    def FormatBatchJobMessage( self, JobId : str, Expiration : int = 20, Cores : int = 1, ScriptName : str = "RunScript", RunScript : str = "", Arguments = [] ) -> str:
        """
            Formats the BatchJobMsg with the given parameters
        """
        ParsedArguments : str = self.GenerateArguments(Arguments)
        return self.BatchJobMsg.format(
            JobId = JobId,
            JobExpiration = str(Expiration),
            JobCores = str(Cores),
            ScriptName = ScriptName,
            RunScript = RunScript,
            Arguments = ParsedArguments
        )
    
    def FormatCloseJobMessage( self, JobId : str ) -> str:
        """
            Formats the CloseJobMsg with the given parameters
        """
        return self.CloseJobMsg.format(
            JobId = JobId
        )
    
    def FormatExecuteScriptMessage( self, JobId : str, ScriptName : str = "Script", Script : str = "", Arguments = []) -> str:
        """
            Formats the ExecuteScriptMsg with the given parameters
        """
        ParsedArguments : str = self.GenerateArguments(Arguments)
        return self.ExecuteScriptMsg.format(
            JobId = JobId,
            ScriptName = ScriptName,
            Script = Script,
            Arguments = ParsedArguments
        )
    
    def FormatGameOpenJSON( self, PlaceId : int, CreatorId : int, JobId : str, ApiKey : str, MaxPlayers : int = 10, GsmInterval : int = 20, PortNumber : int = 53640, CreatorType : str = "User", PlaceVersion : int = 1, MachineAddress : str = "127.0.0.1", UniverseId : int | None = 0):
        """
            Formats the GameOpen JSON with the given parameters used for 2017L+ RCC
        """
        return json.dumps({
            "Mode": "GameServer",
            "Settings": {
                "PlaceId": PlaceId,
                "CreatorId": CreatorId,
                "GameId": JobId,
                "MachineAddress": MachineAddress,
                "MaxPlayers": MaxPlayers,
                "GsmInterval": GsmInterval,
                "MaxGameInstances": 1,
                "PreferredPlayerCapacity": MaxPlayers,
                "UniverseId": PlaceId if UniverseId is None else UniverseId,
                "BaseUrl": "syntax.eco",
                "MatchmakingContextId": 1,
                "CreatorType": CreatorType,
                "PlaceVersion": PlaceVersion,
                "JobId": JobId,
                "PreferredPort": PortNumber,
                "ApiKey": ApiKey,
                "PlaceVisitAccessKey": "None",
                "PlaceFetchUrl": f"https://www.syntax.eco/asset/?id={str(PlaceId)}"
            }
        })


    def ParseGetAllJobsResponse( self, ResponseText : str ):
        """
            Parses the GetAllJobs response into a list of dictionaries
        """
        ParsedResponse = self.ParseXMLResponse(ResponseText)
        JobsList = ParsedResponse["SOAP-ENV:Envelope"]["SOAP-ENV:Body"]["ns1:GetAllJobsResponse"]
        if JobsList is not None and "ns1:GetAllJobsResult" in JobsList:
            JobsList = JobsList["ns1:GetAllJobsResult"]
        else:
            return []
        if type(JobsList) == dict:
            # Only one job
            # Format it into a dict without ns1:
            JobDict = {
                "id" : JobsList["ns1:id"],
                "expirationInSeconds" : JobsList["ns1:expirationInSeconds"],
                "category" : JobsList["ns1:category"],
                "cores" : JobsList["ns1:cores"]
            }
            return [JobDict]
        elif type(JobsList) == list:
            # Multiple jobs
            # Format them into a list of dicts without ns1:
            JobsDictList = []
            for Job in JobsList:
                JobDict = {
                    "id" : Job["ns1:id"],
                    "expirationInSeconds" : Job["ns1:expirationInSeconds"],
                    "category" : Job["ns1:category"],
                    "cores" : Job["ns1:cores"]
                }
                JobsDictList.append(JobDict)
            return JobsDictList
        else:
            # No jobs
            return []
            
        
        