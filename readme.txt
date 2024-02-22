                                                                   
                                                                   
 .M"""bgd `YMM'   `MM`7MN.   `7MFMMP""MM""YMM  db     `YMM'   `MP' 
,MI    "Y   VMA   ,V   MMN.    M P'   MM   `7 ;MM:      VMb.  ,P   
`MMb.        VMA ,V    M YMb   M      MM     ,V^MM.      `MM.M'    
  `YMMNq.     VMMP     M  `MN. M      MM    ,M  `MM        MMb     
.     `MM      MM      M   `MM.M      MM    AbmmmqMA     ,M'`Mb.   
Mb     dM      MM      M     YMM      MM   A'     VML   ,P   `MM.  
P"Ybmmd"     .JMML.  .JML.    YM    .JMML.AMA.   .AMMA.MM:.  .:MMa.
                                                                   

this archive is given to trusted people ( but idrc if it gets leaked )

however some things are removed from the source
- 2016 RCC on gameserver ( don't know how stan will feel about that so i decided not to include it )
- 2021 RCC FFlags ( kyle told me not to ever release )
- private keys for signing
- mailjet email templates

gameserver repo does not have any instructions and i can't be bothered to write any so figure that out yourself
but an important thing is that you have to replace the public key already included and generate your own since
webserver uses that key for authentication to communicate with the gameserver

webserver repo has actual instructions in the readme.md which is used for setting up a development environment
but could also be used for a production webserver ( which i do not recommend unless you know what you are doing )

if you do actually want to fully replicate the original syntax.eco you are going to need to setup a lot of stuff
like the launcher, mailjet, etc

yours truly,
something.else 
22/2/2024