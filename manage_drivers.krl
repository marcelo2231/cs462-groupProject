ruleset manage_drivers {
  meta {
    shares __testing, drivers
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscriptions
  }
  global {
    __testing = { "queries":
      [ { "name": "drivers" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ { "domain": "store", "type": "new_driver", "attrs" : ["name"] }
      , { "domain": "store", "type": "unneeded_driver", "attrs": [ "name" ] }
      , { "domain": "store", "type": "clear_drivers" }
      ]
    }
   drivers = function(){
      ent:drivers.defaultsTo({})
    }
  }
  
  rule add_driver{
    select when store new_driver
    pre{
      name = event:attr("name")
      contains_driver = ent:drivers.filter(function(v,k){ name >< k }).klog("contains_driver")
      contains_driver = (contains_driver == []) => {} | contains_driver
    }
    if contains_driver == {} then
      send_directive("valid_input", {"name": name, "section_id": section_id})
    fired{
      raise wrangler event "child_creation"
        attributes { "name":  name, "rids": ["io.picolabs.logging", "auto_accept"]}
    }else{
      raise store event "duplicated_name"
        attributes{ "name": name }
    }
  }
  
  rule duplicated_name{
    select when store duplicated_name
      send_directive("duplicated_name", {"name": event:attr("name"), "sensors": ent:sensors})
  }
  
  
  rule save_new_driver {
    select when wrangler child_initialized
    pre {
      the_section = {"name": event:attr("name"), "eci": event:attr("eci")}
    }
    fired {
      raise wrangler event "subscription" attributes
       { "name" : the_section{"name"},
         "Rx_role": "store",
         "Tx_role": "driver",
         "channel_type": "subscription",
         "wellKnown_Tx" : the_section{"eci"}
       }
    }
  }
  
  rule pending_subscription_added{
    select when wrangler subscription_added  
    pre{
      name = event:attr("name").klog("name")
      tx = event:attr("wellKnown_Tx").klog("tx")
    }
    fired{
      ent:drivers := ent:drivers.defaultsTo({});
      ent:drivers{[name]} := tx.klog("Section added");
    }
  }
  
  rule unneeded_drivers {
    select when store unneeded_driver
    pre{
      name_to_delete = event:attr("name").klog("name_to_delete")
      exists = ent:drivers.filter(function(v,k){ name_to_delete >< k })
      new_sensors = ent:drivers.filter(function(v,k){ not(name_to_delete >< k) })
    }
    if exists != {} then
      send_directive("unneeded_sensor", {"name_to_delete": name_to_delete, "new_sensors": new_sensors, "exists": exists})
    fired{
      raise wrangler event "subscription_cancellation"
        attributes {"Tx": ent:drivers{[name_to_delete]}};
        
      raise wrangler event "child_deletion"
        attributes {"name": sub_to_delete};
      
      ent:drivers := new_sensors.klog("new_sensors");
    }
  }
  
  
  rule auto_accept {
  select when wrangler inbound_pending_subscription_added
  fired {
    raise wrangler event "pending_subscription_approval"
      attributes event:attrs
    }
  }
  
  rule clear_drivers  {
    select when store clear_drivers
      send_directive("clearing_sensors", {"result": "clearing sensors list"})
    fired{
       ent:drivers := {};
    }
  }
  
}
