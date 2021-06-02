

###### (Automatically generated documentation)

# DR Setpoint Modification Hot Water

## Description
DR Setpoint Modification measure for electric resistance water heaters

## Modeler Description
DR Setpoint Modification measure for electric resistance water heaters

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### DR Event Schedule Name
Name of the schedule to use for setting the EMS code.
**Name:** dr_event_schedule,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### Event Delta T
Amount to lower water heater setpoint by during DR Event.  Use negative number to increase water heater setpoint during event.
**Name:** event_delta_t,
**Type:** Double,
**Units:** degC,
**Required:** true,
**Model Dependent:** false

### Water Heater Setpoint Schedule Name
Name of the water heater setpoint schedule. Will not be changed, but needed for EMS script.
**Name:** water_heater_setpoint_schedule,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### DHW Plant Loop Setpoint Schedule Name
Name of the DHW plant loop setpoint schedule. Will not be changed, but needed for EMS script.
**Name:** plant_setpoint_schedule,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false




