<?php

  /*
  James R. Griffin III
  02/25/12
  AuthorProfile
  Open Library Society
  jrgriffiniii@gmail.com   
   */

  // This is temporary remedy.  Ultimately, the MongoDB's RESTful API will be directly queried.

class AuthorNameSearch {

  var $results;

  function AuthorNameSearch($aunexQueryStr,$host='localhost') {
    
    try {
      $m = new Mongo($host) or die('Could not connect.');
      
      $db = $m->selectDB("authorprofile");
      $coll = $db->selectCollection("auversion");
      
      $regexQuery=new MongoRegex('/^'.$aunexQueryStr.'/u');
      
      // Limit to 5 results.
      $cursor = $coll->find(array('aunex' => $regexQuery),array('aunex' => true))->sort(array('aunex' => true))->limit(5);
      
      foreach ($cursor as $record) {
	// This is meant to resemble a JSON-serialized Author object - the real structure will vary.
	$results[]=array('author' => array('name' => $record['aunex']));
      }
      
      $this->results=json_encode($results);
    } catch(Exception $e) {
      echo 'Could not query the MongoDB database instance: '.$e->getMessage().".\n";
    }
  }

  }

if($_POST['authorNameQuery']) {
  $searchObj=new AuthorNameSearch($_POST['authorNameQuery'],'authorprofile.org');
  echo $searchObj->results;
 }
?>