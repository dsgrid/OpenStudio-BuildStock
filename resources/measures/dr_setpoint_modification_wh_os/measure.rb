# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

# start the measure
class DrSetpointModificationWhOs < OpenStudio::Measure::ModelMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'DrSetpointModificationWhOs'
  end

  # human readable description
  def description
    return 'DR Setpoint Modification measure modified to apply to water heaters'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'DR Setpoint Modification measure modified to apply to water heaters'
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Measure::OSArgumentVector.new

    # DR event schedule name
    dr_event_schedule = OpenStudio::Measure::OSArgument.makeStringArgument("dr_event_schedule", true)
    dr_event_schedule.setDisplayName("DR Event Schedule Name")
    dr_event_schedule.setDescription("Name of the schedule to use for setting the EMS code.")
    dr_event_schedule.setDefaultValue("dr_event_wh")
    args << dr_event_schedule

    # Amount to lower water heater setpoint by during DR Event
    event_delta_t = OpenStudio::Measure::OSArgument.makeDoubleArgument("event_delta_t", true)
    event_delta_t.setDisplayName("Event Delta T")
    event_delta_t.setDescription("Amount to lower water heater setpoint by during DR Event.  Use negative number to increase water heater setpoint during event.")
    event_delta_t.setUnits("degC")
    #event_delta_t.setMinValue(-20.0)
    #event_delta_t.setMaxValue(20.0)
    args << event_delta_t
		
    # water heater setpoint schedule
    water_heater_setpoint_schedule = OpenStudio::Measure::OSArgument.makeStringArgument("water_heater_setpoint_schedule", true)
    water_heater_setpoint_schedule.setDisplayName("Water Heater Setpoint Schedule Name")
    water_heater_setpoint_schedule.setDescription("Name of the water heater setpoint schedule. Will not be changed, but needed for EMS script.")
    water_heater_setpoint_schedule.setDefaultValue("WH Setpoint Temp")
    args << water_heater_setpoint_schedule
		
    # DHW plant loop setpoint schedule
    plant_setpoint_schedule = OpenStudio::Measure::OSArgument.makeStringArgument("plant_setpoint_schedule", true)
    plant_setpoint_schedule.setDisplayName("DHW Plant Loop Setpoint Schedule Name")
    plant_setpoint_schedule.setDescription("Name of the DHW plant loop setpoint schedule. Will not be changed, but needed for EMS script.")
    plant_setpoint_schedule.setDefaultValue("dhw temp")
    args << plant_setpoint_schedule

    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end

    # assign the user inputs to variables
    event_delta_t = runner.getDoubleArgumentValue("event_delta_t", user_arguments)
    water_heater_setpoint_schedule_name = runner.getStringArgumentValue("water_heater_setpoint_schedule", user_arguments)
    plant_setpoint_schedule_name = runner.getStringArgumentValue("plant_setpoint_schedule", user_arguments)
    dr_event_schedule_name = runner.getStringArgumentValue("dr_event_schedule", user_arguments)

    # confirm schedules exist and load them

    # confirm water heater setpoint schedule exists
      water_heater_setpoint_schedule = model.getObjectByTypeAndName('OS_Schedule_Ruleset'.to_IddObjectType, water_heater_setpoint_schedule_name)
      if water_heater_setpoint_schedule.is_initialized
        water_heater_setpoint_schedule = water_heater_setpoint_schedule.get.to_ScheduleRuleset.get
      else
				# look for schedule constant
				water_heater_setpoint_schedule = model.getObjectByTypeAndName('OS_Schedule_Constant'.to_IddObjectType, water_heater_setpoint_schedule_name)
				if water_heater_setpoint_schedule.is_initialized
					water_heater_setpoint_schedule = water_heater_setpoint_schedule.get.to_ScheduleConstant.get
				else
					runner.registerError("ERROR.  Schedule #{water_heater_setpoint_schedule_name} cannot be loaded")
					return false
				end	
      end

    # confirm dhw plant loop setpoint schedule exists
      plant_setpoint_schedule = model.getObjectByTypeAndName('OS_Schedule_Ruleset'.to_IddObjectType, plant_setpoint_schedule_name)
      if plant_setpoint_schedule.is_initialized
        plant_setpoint_schedule = plant_setpoint_schedule.get.to_ScheduleRuleset.get
      else
				# look for schedule constant
				plant_setpoint_schedule = model.getObjectByTypeAndName('OS_Schedule_Constant'.to_IddObjectType, plant_setpoint_schedule_name)
				if plant_setpoint_schedule.is_initialized
					plant_setpoint_schedule = plant_setpoint_schedule.get.to_ScheduleConstant.get
				else
					runner.registerError("ERROR.  Schedule #{plant_setpoint_schedule_name} cannot be loaded")
					return false
				end	
      end

    # confirm dr event schedule exists
		# runner.registerInfo("Loading DR Event Schedule: #{dr_event_schedule_name}")
      dr_event_schedule = model.getObjectByTypeAndName('OS_Schedule_Ruleset'.to_IddObjectType, dr_event_schedule_name)
      if dr_event_schedule.is_initialized
        dr_event_schedule = dr_event_schedule.get.to_ScheduleRuleset.get
      else
				dr_event_schedule = model.getObjectByTypeAndName('OS_Schedule_File'.to_IddObjectType, dr_event_schedule_name)
				if dr_event_schedule.is_initialized
					dr_event_schedule = dr_event_schedule.get.to_ScheduleFile.get
				else
					dr_event_schedule = model.getObjectByTypeAndName('OS_Schedule_FixedInterval'.to_IddObjectType, dr_event_schedule_name)
					if dr_event_schedule.is_initialized
						dr_event_schedule = dr_event_schedule.get.to_ScheduleFixedInterval.get
					else
						runner.registerError("ERROR.  Schedule #{dr_event_schedule_name} cannot be loaded")
						return false
					end	
				end	
      end

    # copy the setpoint schedules
    schedules_to_copy = Array[water_heater_setpoint_schedule, plant_setpoint_schedule]
    schedules_to_copy.each do |schedule|
      schedule_copy = schedule.clone(model)
      schedule_copy = schedule_copy.to_ScheduleRuleset.get
      schedule_copy.setName("#{schedule.name.get.to_s}_copy")
      runner.registerInfo("Schedule '#{schedule_copy.name}' was added.")
    end

    # add ems code to modify setpoint schedules
    # create dr schedule sensor
    dr_schedule_value = OpenStudio::Model::EnergyManagementSystemSensor.new(model,"Schedule Value")
    dr_schedule_value.setName("#{dr_event_schedule_name}_sen")
    dr_schedule_value.setKeyName(dr_event_schedule_name)

    # create existing water heater setpoint sensor
    existing_water_heater_setpoint = OpenStudio::Model::EnergyManagementSystemSensor.new(model,"Schedule Value")
    existing_water_heater_setpoint.setName("existing_water_heater_setpoint_sen")
    existing_water_heater_setpoint.setKeyName("#{water_heater_setpoint_schedule_name}_copy")

    # create existing dhw plant loop setpoint sensor
    existing_plant_setpoint = OpenStudio::Model::EnergyManagementSystemSensor.new(model,"Schedule Value")
    existing_plant_setpoint.setName("existing_plant_setpoint_sen")
    existing_plant_setpoint.setKeyName("#{plant_setpoint_schedule_name}_copy")

    # create water heater setpoint actuator
    water_heater_setpoint_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(water_heater_setpoint_schedule,"Schedule:Year","Schedule Value")
    water_heater_setpoint_actuator.setName("#{water_heater_setpoint_schedule_name}_act")

    # create dhw plant loop setpoint actuator
    plant_setpoint_actuator = OpenStudio::Model::EnergyManagementSystemActuator.new(plant_setpoint_schedule,"Schedule:Year","Schedule Value")
    plant_setpoint_actuator.setName("#{plant_setpoint_schedule_name}_act")
    
    # create ems program
    setpoint_shift_program = OpenStudio::Model::EnergyManagementSystemProgram.new(model)
    setpoint_shift_program.setName("setpoint_shift_program")
    setpoint_shift_program_body = <<-EMS
      IF (@Abs #{dr_schedule_value.name.get.to_s}) > 1.0E-8
        SET #{water_heater_setpoint_actuator.name.get.to_s} = #{existing_water_heater_setpoint.name.get.to_s} - #{event_delta_t} * #{dr_schedule_value.name.get.to_s}
        SET #{plant_setpoint_actuator.name.get.to_s} = #{existing_plant_setpoint.name.get.to_s} - #{event_delta_t} * #{dr_schedule_value.name.get.to_s}
      ELSE
        SET #{water_heater_setpoint_actuator.name.get.to_s} = #{existing_water_heater_setpoint.name.get.to_s}
        SET #{plant_setpoint_actuator.name.get.to_s} = #{existing_plant_setpoint.name.get.to_s}
			ENDIF	
    EMS
    setpoint_shift_program.setBody(setpoint_shift_program_body)
    
    # create ems program calling manager
    setpoint_shift_program_calling_manager = OpenStudio::Model::EnergyManagementSystemProgramCallingManager.new(model)
    setpoint_shift_program_calling_manager.setName("setpoint_shift_program_calling_manager")
    setpoint_shift_program_calling_manager.setProgram(setpoint_shift_program,0)
    setpoint_shift_program_calling_manager.setCallingPoint("BeginTimestepBeforePredictor")
    
    # specify ems output
    # ems_output = model.getOutputEnergyManagementSystem
    # ems_output.setActuatorAvailabilityDictionaryReporting("Verbose")
    # ems_output.setInternalVariableAvailabilityDictionaryReporting("Verbose")
    # ems_output.setEMSRuntimeLanguageDebugOutputLevel("Verbose")

    return true
  end
end

# register the measure to be used by the application
DrSetpointModificationWhOs.new.registerWithApplication
