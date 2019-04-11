ruleset gossipfinal {
  meta {
    shares __testing, state, temp_logs, getPeer, getMessage, send, update, smart_tracker, sequence_id
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscriptions
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" },
      { "name": "state" },
      { "name": "temp_logs" },
      { "name": "getPeer" },
      { "name": "getMessage" },
      { "name": "send" },
      { "name": "update" },
      { "name": "sequence_id" },
      { "name": "smart_tracker" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "gossip", "type": "clear" },
        { "domain": "gossip", "type": "fake_data" },
        { "domain": "gossip", "type": "fake_data_empty" },
        { "domain": "gossip", "type": "run" },
        { "domain": "gossip", "type": "heartbeat" },
        { "domain": "gossip", "type": "new_temperature", "attrs": [ "temperature", "timestamp" ] }
      ]
    }
     getPeer = function(){
       mysubscriptions = subscriptions:established();
       mysubscriptions.map(function(x){
          eci = x["Tx"].klog("Tx");
          role = x["Tx_role"];
          valid = (role == "store");
          url = (valid) => "http://localhost:8080/sky/cloud/" + eci + "/io.picolabs.gossipfinal/state" | "";
          content = (valid) => http:get(url){"content"}.decode() | null;
          content.map(function(v, k){
            contains = not ent:state.any(function(x){
                x == v;
              });
            ((contains) => v | null);
          }).filter(function(y){y!=null});
       }).filter(function(x){x!=[]})[0];
     };
     
     addEcis = function(ecisToBeAdded){
       ecisToBeAdded.map(function(x){
          ent:state.defaultsTo([]).append(x);
       })
     }
     
    state = function(){
      ent:state.defaultsTo([])
    } 
  }
  
  rule run{
    select when gossip run
    fired{
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": 15})
    }
  }
  
  rule gossip_heartbeat{
    select when gossip heartbeat
    pre{
      ecisToBeAdded = getPeer().klog("SUBSCRIBERRR");
      valid = ecisToBeAdded != [{}];
    }
    if valid then
      send_directive("Result", {"ecisToBeAdded": ecisToBeAdded, "valid": valid, "result": result})
    fired{
      ent:state := addEcis(ecisToBeAdded)[1];
       schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": 15})
    }else{
       schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": 15})
    }
  }
  
  rule new_driver{
    select when gossip new_driver
    pre{
      eci = event:attrs{"eci"}
    }
    always{
      ent:state := ent:state.defaultsTo([]).append(eci);
    }
  }
  
  // For testing:
  
  rule clear_all{
    select when gossip clear
    always{
      ent:state := [];
    }
  }
  
  rule fake_data{
    select when gossip fake_data
    always{
      ent:state := ent:state.defaultsTo([]).append("eci3");
    }
  }
  
    rule fake_data_empty{
    select when gossip fake_data_empty
    always{
      ent:state := ent:state.defaultsTo([]).append("eci1");
    }
  }
}
