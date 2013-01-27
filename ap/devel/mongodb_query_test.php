<?php

$aunexQueryStr=$_POST['nameStr'];
//$aunexQueryStr='Thomas ';

$m = new Mongo(); // connect
$db = $m->selectDB("authorprofile");
$coll = $db->selectCollection("auversion");

//  $regexObj = new MongoRegex("/^Nicolas/i"); 
//$regexQuery=new MongoRegex('/^'.$aunexQueryStr.'/u');
$regexQuery=new MongoRegex('/^'.$aunexQueryStr.'/u');

//echo var_dump($regexQuery);

//$aunexQueryStr='Thomas Krichel';
//$cursor = $coll->find(array('aunex' => $aunexQueryStr))->limit(10);
$cursor = $coll->find(array('aunex' => $regexQuery),array('aunex' => true))->sort(array('aunex' => true))->limit(10);

//while ($cursor->hasNext())
//  {
//   $clientObj = $cursor->getNext();
//    echo var_dump($clientObj).'<br />';
    //    echo "Client Name: ".$clientObj['aunex']."</br>";
//  } 

foreach ($cursor as $record) {
  echo '<div><span><q>'.$record['aunex'].'</q></span></div>';
  //var_dump($record);
}


?>