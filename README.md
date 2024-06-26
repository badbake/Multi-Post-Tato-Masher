# Multi_Post_Tato_Masher
 Script for running multiple versions of Post service.exe
 
 Intended to be used alongside running go-spacemesh in a 1:N configuration.
 
 Allows for multiple post directorys to be used from one 'service.exe'<br>
 The script starts by calculating the next Cycle Gap, (by default using standard 12hr POET)<br>
 It will then sleep until that time.<br><br>
 The script will then start 'service.exe' with the user configured arguments, adjusted for each set of POST data.<br>
 It will then use 'grpcurl.exe' (source newest version yourself) to monitor the status of the proving, and upon confirmation of the node accepting the proof;<br>
 The script will then end that instance of 'service.exe';<br>
 Then move onto the next set of Post Data and arguments for 'service.exe';
 Running untill all instances have finished;
 It will then calculate the time to the next default POET 12HR Cycle Gap start time;
 And sleep until 10 minutes before (by default), when it will start the cycle again.

## Setup
 Suggest getting and editing using Notepad++ but can be edited with whatever text editor you use.

 1) Open 'Masher_Config.ps1' in a text editor.
  ![Masher_Config](https://github.com/badbake/Multi-Post-Tato-Masher/blob/04d433cd8a5553f1c99d168296919dde4502ebad/readme_content/masher_config.png)
 2) Change all Post Data settings to match your particular use case. Add/Remove Post Services as needed. For example, my 1:N setup.
  ![my_1N_masher_config](https://github.com/badbake/Multi-Post-Tato-Masher/blob/0f70d42c452c118ac428d06217cb6a29b3c9a792/readme_content/my_1N_masher_config.png)
 3) (OPTIONAL) You can also set the log level displayed both on the console and also in the output log file. You can also choose to save the service.exe log files if you choose. Also you can adjust the interval at which the script checks the node/proving.
  ![optional](https://github.com/badbake/Multi-Post-Tato-Masher/blob/5ccafc4f182d8d753dadb7eda4a3c598d3347160/readme_content/optional.png)
 5) Ensure you have enabled script execution permisions for remote scripts. Unblock/Unlock both .ps1 files. Node must be running (there is no logic yet for checking this, it is built assuming node is running)
 6) Run 'BadBakes_Multi_Post-tato_Masher__V*_MainNet.ps1'

## Running
 1) If properly configured it should check to see if any of the post data sets you configured in Step 2 return "PROVING" from the node, if they do (new data set or script started during CG) it will run those instances of that POST data set.
 2) Otherwise if none are found requiring a proof, it will calculate the time to the next Cycle Gap and display the time and date and remaining time until.
   ![running](https://github.com/badbake/Multi-Post-Tato-Masher/blob/3c72942f65ad28db33a48479876e091291507b9c/readme_content/running.png)
 4) Once the Cycle Gap is reached, the script will start and run each set of Post data set in Masher_Config, 1 at a time, allowing each to complete proving and it being accepted by the node.
 5) Once it confirms the node has accepted the proof, it will close that instance of service.exe and move onto the next set of Post Data. Until all have completed.
 6) Once all have been ran, the next cycle gap is calculated and the cycle repeats.

