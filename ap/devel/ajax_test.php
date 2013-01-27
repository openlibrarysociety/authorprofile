<!-- testing -->
<html>
<head>
<script type="text/javascript">
   function loadXMLDoc(aunexQuery)
{
  document.getElementById('aunexQueryResults').innerHTML=('Loading...');
  xmlhttp=new XMLHttpRequest();
  xmlhttp.open("POST","mongodb_query_test.php",true);
  xmlhttp.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
  xmlhttp.setRequestHeader("Content-length", 1);
  xmlhttp.setRequestHeader("Connection", "close");
  xmlhttp.onreadystatechange = function() {//Call a function when the state changes.
    if(xmlhttp.readyState == 4 && xmlhttp.status == 200) {
      
      document.getElementById('aunexQueryResults').innerHTML=(xmlhttp.responseText);
    }
  }
  xmlhttp.send('nameStr='+aunexQuery);
}
   function checkQueryStrLen()
   {
     var aunexQuery=document.getElementById('aunexQuery').value;
     if(aunexQuery.length >= 3) {
       loadXMLDoc(aunexQuery);
     } else {
       document.getElementById('aunexQueryResults').innerHTML='';
     }
     
   }
</script>
</head>
<body>
<?php

echo getcwd();

?>
</body>
<div>query interface
<input id="aunexQuery" type="text" onkeyup="checkQueryStrLen()" /></div>
<div id="aunexQueryResults" />

</body></html>