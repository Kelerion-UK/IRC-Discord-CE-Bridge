string url; key http_request_id;
string server_url="http://xxxchatters.com";
string server_port="1111"; // This is unique for each channel - for demo purposes this is set to Koroba
float HEALTHCHECK_INTERVAL = 10.0;
key healthCheckKey=NULL_KEY;
integer ERROR_TRIES = 0;

init(){
    http_request_id = llHTTPRequest(server_url+":"+server_port+"/?URI="+llEscapeURL(url), [], "");
    // Start up request a URL and listen on channel 0
    llRequestURL();
    llListen(0,"","","");
    llSetTimerEvent(HEALTHCHECK_INTERVAL);
}

check(){
    healthCheckKey = llHTTPRequest(server_url+":"+server_port+"/?PING=1", [], "");    
}

state weGotProblems {
    state_entry() 
    {
        llOwnerSay("We got some problems here with communicating with the IRC-Replay. Resetting Script in 10 mins.");
        llSetTimerEvent(600);
    }   
    
    timer() {
        llResetScript();
    }
}

default {

   state_entry() 
   {
        init();
   }
   
    on_rez(integer startParam){
        init();   
    }
    
    timer() {
        check();    
    }
   
   changed(integer What) 
   {
       // On a region restart request a new URL
       if (What & CHANGED_REGION_START) 
       {
           init();
       }
   }
   
   http_request(key ID, string Method, string Body) 
   {
       if (Method == URL_REQUEST_GRANTED) 
       {
           //If the URL was granted save the URL and send it to the server
           llOwnerSay("Url Request Granted");
           url = Body;
           http_request_id = llHTTPRequest(server_url+":"+server_port+"/?URI="+llEscapeURL(Body), [], "");
       } 
       else if (Method == URL_REQUEST_DENIED) 
       {
          // We are boned
          llOwnerSay("No URLs");
       } 
       else if (Method == "GET") 
       {
           // Get the data sent to us, say it on channel 0 and respond with a 200
           llSay(0,llUnescapeURL(llGetHTTPHeader(ID, "x-query-string")));
           llHTTPResponse(ID, 200, "Hello there !");        
       }
   }
   
   listen(integer channel,string name, key id,string msg)
   {
       // Send all channel 0 data to the server
       http_request_id = llHTTPRequest(server_url+":"+server_port+"/?MSG="+llEscapeURL("<"+name+"> "+msg), [], "");
   }
   
   http_response(key request_id, integer status, list metadata, string body)
   {
       //Check http response after sending data from listen or a URI update
       if (request_id == http_request_id)
       {
          //Do some error checking for status !=200
          return;
       }
       else if(request_id ==healthCheckKey){
           if(status == 200 && body == "PONG"){
                return;
           }
           ERROR_TRIES++;
           if(ERROR_TRIES > 2)
                state weGotProblems;
            
            llOwnerSay("Response from healthcheck status: " + status + " body: " + body);   
            init();
        }
   }
}
