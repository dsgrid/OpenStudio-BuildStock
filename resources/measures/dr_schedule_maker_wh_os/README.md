

###### (Automatically generated documentation)

# dr_schedule_maker_wh_os

## Description
Modified version of the dr schedule maker os measure that is applicable to water heaters

## Modeler Description
Modified version of the dr schedule maker os measure that is applicable to water heaters

## Measure Type
ModelMeasure

## Taxonomy


## Arguments


### Name of DR Schedule
The name of the Schedule used by DR setpoint measures for EMS code.
**Name:** schedule_name,
**Type:** String,
**Units:** ,
**Required:** true,
**Model Dependent:** false

### DR Event Start Time
The hour of the day that the daily DR event begins at; fractional numbers are allowed.
**Name:** event_start_time,
**Type:** Double,
**Units:** hr,
**Required:** true,
**Model Dependent:** false

### DR Event Duration
The duration of the daily DR event in hours.
**Name:** event_duration,
**Type:** Double,
**Units:** hr,
**Required:** true,
**Model Dependent:** false




