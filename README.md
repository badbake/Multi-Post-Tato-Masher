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
