# Multi_Post_Tato_Masher
 Script for running multiple versions of Post service.exe
 
 Intended to be used alongside running go-spacemesh in a 1:N configuration.
 
 Allows for multiple post directories to be used from one 'service.exe'<br>
 The script starts by calculating the next Cycle Gap, (by default using standard 12hr POET)<br>
 It will then sleep until that time.<br><br>
 The script will then start 'service.exe' with the user configured arguments, adjusted for each set of POST data.<br>
 It will then use 'grpcurl.exe' (source newest version yourself) to monitor the status of the proving, and upon confirmation of the node accepting the proof;<br>
 The script will then end that instance of 'service.exe';<br>
 Then move onto the next set of Post Data and arguments for 'service.exe';
 Running untill all instances have finished;
 It will then calculate the time to the next default POET 12HR Cycle Gap start time;
 And sleep until the next Cycle Gap, when it will start the process again.

 The script should display all information in the users local time zone. 

## Motivation
 I originally came up with the idea for making this script when I saw that the 26 SU plot on my miniPC finished in just a couple hours,<br>
 so in theory I could handle proving a lot more data in the 12 hour cycle gap.<br><br>
 So I wanted to maximize what my miniPC could prove, but I couldnt expand its internal NvMe drive any more than it currently is, nor can I increase it's 16gb of ram.<br><br>
 So with these limiting factors in mind, I decided that going with a 1:N setup with multiple sets of POST Data was my best option...<br>
 BUT having only 16 gb of RAM, my miniPC would not be able to handle running multiple versions of service.exe at a time.<br><br>
 So my solution was creating this, <b>Badbake's Multi-Post-Tato-Masher</b>! 

 So if you are like me and are trying to do a LOT with a little! This script might be for you!

Please Take Note: I built this for my personal use. I tried to make it a user-friendly type script that I could share with others that might need it. As such I just want to state I am not responsible for your usage of this script if you choose to use it yourself.

## Setup

 Download/Git both the Masher_config.ps1 and the current version of the Multi-Post-Tato-Masher. Place both in Node directory with service.exe in same location. (could vary based on your setup, more advanced users will need to tweak some stuff.)

Suggest getting and editing using Notepad++ but can be edited with whatever text editor you use.

 1) Open 'Masher_Config.ps1' in a text editor.
  ![Masher_Config](https://github.com/badbake/Multi-Post-Tato-Masher/blob/7aa70c90b84600bb9f934af74dc0d2ff917a903b/readme_content/masher_config.png)
 2) Change all Post Data settings to match your particular use case. Add/Remove Post Services as needed. For example, my 1:N setup.
  ![my_1N_masher_config](https://github.com/badbake/Multi-Post-Tato-Masher/blob/0f70d42c452c118ac428d06217cb6a29b3c9a792/readme_content/my_1N_masher_config.png)
 3) (OPTIONAL) You can also set the log level displayed both on the console and also in the output log file. You can also choose to save the service.exe log files if you choose. Also you can adjust the interval at which the script checks the node/proving.
  ![optional](https://github.com/badbake/Multi-Post-Tato-Masher/blob/623d47c7c96759fe7eb31c0978bd6405315df3b5/readme_content/optional.png)
 5) Ensure you have enabled script execution permisions for remote scripts. Unblock/Unlock both .ps1 files. Node must be running (there is no logic yet for checking this, it is built assuming node is running)
 6) In 'Masher_Config' also ensure location of grpcurl is correct for you file structure setup.
 7) Run 'BadBakes_Multi_Post-tato_Masher__V*_MainNet.ps1'

## Running
 1) If properly configured it should check to see if any of the post data sets you configured in Step 2 return "PROVING" from the node, if they do (new data set or script started during CG) it will run those instances of that POST data set.
 2) Otherwise if none are found requiring a proof, it will calculate the time to the next Cycle Gap and display the time and date and remaining time until.
   ![running](https://github.com/badbake/Multi-Post-Tato-Masher/blob/3c72942f65ad28db33a48479876e091291507b9c/readme_content/running.png)
 4) Once the Cycle Gap is reached, the script will start and run each set of Post data set in Masher_Config, 1 at a time, allowing each to complete proving and it being accepted by the node.
 5) During Proving, It will display if the proof is in k2pow stage or Post Data Read %, if multiple passes are required it will display that as well.
   ![proving](https://github.com/badbake/Multi-Post-Tato-Masher/blob/6723569be620d84dc85ba65a172f78441c10daea/readme_content/proving.png)
 6) Once it confirms the node has accepted the proof, it will close that instance of service.exe and move onto the next set of Post Data. Until all have completed.
 7) Once all have been ran, the next cycle gap is calculated and the cycle repeats.

