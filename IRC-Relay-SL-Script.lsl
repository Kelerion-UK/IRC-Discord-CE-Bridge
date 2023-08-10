 // // Copyright (C) 2010 Robin Cornelius <robin.cornelius@gmail.com> // // This program is free software: you can redistribute it and/or modify // it under the terms of the GNU General Public License as published by // the Free Software Foundation, either version 3 of the License, or // (at your option) any later version. // // This program is distributed in the hope that it will be useful, // but WITHOUT ANY WARRANTY; without even the implied warranty of // MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the // GNU General Public License for more details. // // You should have received a copy of the GNU General Public License // along with this program. If not, see <http://www.gnu.org/licenses/>. //

//Heavy adaptions by Kelerion for use on the xxxchatters.com network.


string url; key http_request_id;
string server_url="http://xxxchatters.com";
string server_port="1110"; // This is unique for each channel
 
default {

   touch_start(integer num_detected)
   {
       if(llDetectedKey(0)==llGetOwner())
       {
           // Rsend the URI to the server if the owner touches us
           http_request_id = llHTTPRequest(server_url+":"+server_port+"/?URI="+llEscapeURL(url), [], "");
           
       }
   }
   
   state_entry() 
   {
       // Start up request a URL and listen on channel 0
       llRequestURL();
       llListen(0,"","","");
   }
   
   changed(integer What) 
   {
       // On a region restart request a new URL
       if (What & CHANGED_REGION_START) 
       {
           llRequestURL();
       }
   }
   
   http_request(key ID, string Method, string Body) 
   {
       if (Method == URL_REQUEST_GRANTED) 
       {
           //If the URL was granted save the URL and send it to the server
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
       llHTTPRequest(server_url+":"+server_port+"/?MSG="+llEscapeURL("<"+name+"> "+msg), [], "");
   }
   
   http_response(key request_id, integer status, list metadata, string body)
   {
       //Check http response after sending data from listen or a URI update
       if (request_id == http_request_id)
       {
          //Do some error checking for status !=200
       }
   }
}
