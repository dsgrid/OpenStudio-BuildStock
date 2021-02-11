# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'erb'

# start the measure
class ReportElectricWaterHeaterInformation < OpenStudio::Measure::ReportingMeasure
  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'Report Electric Water Heater Information'
  end

  # human readable description
  def description
    return 'Reports out information on electric water heaters, especially tank volume, power capacity, ambient temperature source, and schedule names.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Reports out information on electric water heaters, especially tank volume, power capacity, ambient temperature source, and schedule names. Currently only applies to buildings with a single electric resistance water heater.'
  end

  # define the arguments that the user will input
  def arguments
    args = OpenStudio::Measure::OSArgumentVector.new

    # this measure does not require any user arguments, return an empty list

    return args
  end
  
  # define the outputs that the measure will create
  def outputs
    result = OpenStudio::Measure::OSOutputVector.new

    numeric_properties = [
      "tank_volume_m3",
      "off_cycle_loss_coefficient_W_per_K",
      "on_cycle_loss_coefficient_W_per_K",
      "heater_thermal_efficiency_fraction",
			"heat_pump_rated_cop",
      "heater_maximum_capacity_W",
			"heat_pump_heating_capacity_W"
    ]
    string_properties = [
      "setpoint_temperature_schedule",
      "use_flow_rate_fraction_schedule",
      "ambient_temperature_indicator", # Schedule, Zone, or Outdoors
      "ambient_temperature_schedule",
      "ambient_temperature_zone"
    ]
    
    numeric_properties.each do |numeric_property|
      result << OpenStudio::Measure::OSOutput.makeDoubleOutput(numeric_property)
    end
    string_properties.each do |string_property|
      result << OpenStudio::Measure::OSOutput.makeStringOutput(string_property)
    end

    return result
  end
  
  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  # Warning: Do not change the name of this method to be snake_case. The method must be lowerCamelCase.
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)

    result = OpenStudio::IdfObjectVector.new

    # use the built-in error checking
    if !runner.validateUserArguments(arguments, user_arguments)
      return result
    end

    return result
  end

  # define what happens when the measure is run
  def run(runner, user_arguments)
    super(runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments, user_arguments)
      return false
    end

    # get the last model and sql file
    model = runner.lastOpenStudioModel
    if model.empty?
      runner.registerError("Cannot find last model.")
      return false
    end
		model = model.get
		
		# get water heater(s)
		water_heaters = []
		water_heaters += model.getWaterHeaterMixeds
		num_water_heater_mixeds = water_heaters.length
		water_heaters += model.getWaterHeaterStratifieds
		num_water_heater_stratifieds = water_heaters.length - num_water_heater_mixeds
		
		heat_pumps = []
		heat_pumps += model.getWaterHeaterHeatPumpWrappedCondensers
		num_heat_pumps = heat_pumps.length
				
		# puts "The model has #{num_water_heater_mixeds} WaterHeater:Mixed objects"
		# puts "The model has #{num_water_heater_stratifieds} WaterHeater:Stratified objects"
		# puts "The water heater array has a length of #{water_heaters.length}"

    # this reporting measure is only applicable if there is a single 
    # WaterHeater:Mixed or WaterHeater:Stratified with Electricity as the Heater Fuel Type
		# check number of water heaters
    if water_heaters.length != 1
      runner.registerAsNotApplicable("Measure is not applicable because the number of WaterHeater:Mixed and/or WaterHeater:Stratified objects is #{water_heaters.length}, not 1.")
      return true
    end
    water_heater = water_heaters[0]
		
		if num_heat_pumps > 1
      runner.registerAsNotApplicable("Measure is not applicable because the number of WaterHeater:HeatPump:WrappedCondenser objects #{num_heat_pumps} is greater than 1.")
      return true
		end
		
		if num_heat_pumps == 1
			heat_pump = heat_pumps[0]
		end
		
		# get water heater type
		if num_water_heater_mixeds == 1
			water_heater_type = "WaterHeater:Mixed"
		elsif num_water_heater_stratifieds == 1
			water_heater_type = "WaterHeater:Stratified"
		else
			runner.registerError("Unexpected number of water heaters: #{num_water_heater_mixeds} WaterHeater:Mixed and #{num_water_heater_stratifieds} WaterHeater:Stratified")
			return false
		end
		# check water heater fuel type
		heater_fuel_type = water_heater.heaterFuelType
    if heater_fuel_type != "Electricity"
      runner.registerAsNotApplicable("Measure is not applicable because the #{water_heater_type} uses a fuel (#{heater_fuel_type}) other than electricity.")
      return true
    end
		
    # register tank volume
		if water_heater.tankVolume.is_initialized
			runner.registerValue("tank_volume_m3", water_heater.tankVolume.get)
			runner.registerInfo("Registering #{water_heater.tankVolume.get} for tank_volume_m3")
		else
			runner.registerError("Tank volume not specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
			return false
		end
		
		# register loss coefficients
		if water_heater_type == "WaterHeater:Mixed"
			# register off cycle loss coefficient
			if water_heater.offCycleLossCoefficienttoAmbientTemperature.is_initialized
				runner.registerValue("off_cycle_loss_coefficient_W_per_K", water_heater.offCycleLossCoefficienttoAmbientTemperature.get)
				runner.registerInfo("Registering #{water_heater.offCycleLossCoefficienttoAmbientTemperature.get} for off_cycle_loss_coefficient_W_per_K")
			else
				runner.registerError("Off cycle loss coefficient not specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
				return false
			end
			# register on cycle loss coefficient
			if water_heater.onCycleLossCoefficienttoAmbientTemperature.is_initialized
				runner.registerValue("on_cycle_loss_coefficient_W_per_K", water_heater.onCycleLossCoefficienttoAmbientTemperature.get)
				runner.registerInfo("Registering #{water_heater.onCycleLossCoefficienttoAmbientTemperature.get} for on_cycle_loss_coefficient_W_per_K")
			else
				runner.registerError("On cycle loss coefficient not specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
				return false
			end
		elsif water_heater_type == "WaterHeater:Stratified"
			tank_height = 0
			# get tank height
			if water_heater.tankHeight.is_initialized
				tank_height = water_heater.tankHeight.get
			else
				runner.registerError("Tank height not specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
				return false
			end
			# calculate tank surface area
			pi = Math::PI
			tank_volume = water_heater.tankVolume.get
			tank_radius = Math.sqrt(tank_volume/(pi*tank_height))
			tank_surface_area = 2*pi*tank_radius*(tank_height + tank_radius)
			# get area normalized loss coefficient
			if water_heater.uniformSkinLossCoefficientperUnitAreatoAmbientTemperature.is_initialized
				loss_coeff_area_normalized = water_heater.uniformSkinLossCoefficientperUnitAreatoAmbientTemperature.get
				# register off cycle loss coefficient
				runner.registerValue("off_cycle_loss_coefficient_W_per_K", loss_coeff_area_normalized*tank_surface_area)
				runner.registerInfo("Registering #{loss_coeff_area_normalized*tank_surface_area} for off_cycle_loss_coefficient_W_per_K")
				# register on cycle loss coefficient
				runner.registerValue("on_cycle_loss_coefficient_W_per_K", loss_coeff_area_normalized*tank_surface_area)
				runner.registerInfo("Registering #{loss_coeff_area_normalized*tank_surface_area} for on_cycle_loss_coefficient_W_per_K")
			else
				runner.registerError("Area normalized loss coefficient not specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
				return false
			end
		end
		
		# register heater thermal efficiency
		if water_heater_type == "WaterHeater:Mixed"
			if water_heater.heaterThermalEfficiency.is_initialized
				runner.registerValue("heater_thermal_efficiency_fraction", water_heater.heaterThermalEfficiency.get)
				runner.registerInfo("Registering #{water_heater.heaterThermalEfficiency.get} for heater_thermal_efficiency_fraction")
			else
				runner.registerError("Heater thermal efficiency not specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
				return false
			end
		elsif water_heater_type == "WaterHeater:Stratified"
			runner.registerValue("heater_thermal_efficiency_fraction", water_heater.heaterThermalEfficiency)
			runner.registerInfo("Registering #{water_heater.heaterThermalEfficiency} for heater_thermal_efficiency_fraction")
		end
		
		# register heat pump efficiency and heating capacity
		unless num_heat_pumps == 1
			runner.registerValue("heat_pump_rated_cop", "NA")
			runner.registerInfo("Registering NA for heat_pump_rated_cop")
			runner.registerValue("heat_pump_heating_capacity_W", "NA")
			runner.registerInfo("Registering NA for heat_pump_heating_capacity_W")
		else
			# get heating coil
			dx_coil = heat_pump.dXCoil.to_CoilWaterHeatingAirToWaterHeatPumpWrapped
			if dx_coil.is_initialized
				dx_coil = dx_coil.get
				runner.registerValue("heat_pump_rated_cop", dx_coil.ratedCOP)
				runner.registerInfo("Registering #{dx_coil.ratedCOP} for heat_pump_rated_cop")
				runner.registerValue("heat_pump_heating_capacity_W", dx_coil.ratedHeatingCapacity)
				runner.registerInfo("Registering #{dx_coil.ratedHeatingCapacity} for heat_pump_heating_capacity_W")
			else
				runner.registerError("Unexpected DX coil object for heat pump; expecting CoilWaterHeatingAirToWaterHeatPumpWrapped")
				return false
			end
		end
		
		# register maximum capacity
		if water_heater_type == "WaterHeater:Mixed"
			if water_heater.heaterMaximumCapacity.is_initialized
				runner.registerValue("heater_maximum_capacity_W", water_heater.heaterMaximumCapacity.get)
				runner.registerInfo("Registering #{water_heater.heaterMaximumCapacity.get} for heater_maximum_capacity_W")
			else
				runner.registerError("Heater maximum capacity not specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
				return false
			end
		elsif water_heater_type == "WaterHeater:Stratified"
			# get heater 1 capacity
			heater_1_capacity = 0
			if water_heater.heater1Capacity.is_initialized
				heater_1_capacity = water_heater.heater1Capacity.get
			else
				runner.registerError("Heater 1 capacity not specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
				return false
			end
			# get heater 2 capacity
			heater_2_capacity = water_heater.heater2Capacity
			# determine heater priority control
			heater_priority_control = water_heater.heaterPriorityControl
			# register maximum heater capacity
			if heater_priority_control == "MasterSlave"
				# modified to report heater_1 capacity since it will always have priority
				# and currently the measure crashes if heater_1 and heater_2 have different setpoints
				runner.registerValue("heater_maximum_capacity_W", heater_1_capacity)
				runner.registerInfo("Registering #{heater_1_capacity} for heater_maximum_capacity_W")
				# runner.registerValue("heater_maximum_capacity_W", [heater_1_capacity,heater_2_capacity].max)
				# runner.registerInfo("Registering #{[heater_1_capacity,heater_2_capacity].max} for heater_maximum_capacity_W")
			elsif heater_priority_control == "Simultaneous"
				runner.registerValue("heater_maximum_capacity_W", heater_1_capacity + heater_2_capacity)
				runner.registerInfo("Registering #{heater_1_capacity + heater_2_capacity} for heater_maximum_capacity_W")
			else
				runner.registerError("Unexpected Heater Priority Control specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
				return false
			end
		end
		
		# register setpoint temperature schedule name
		unless num_heat_pumps == 1
			if water_heater_type == "WaterHeater:Mixed"
				if water_heater.setpointTemperatureSchedule.is_initialized
					runner.registerValue("setpoint_temperature_schedule", water_heater.setpointTemperatureSchedule.get.name.get.to_s)
					runner.registerInfo("Registering #{water_heater.setpointTemperatureSchedule.get.name.get.to_s} for setpoint_temperature_schedule")
				else
					runner.registerError("Setpoint temperature schedule not specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
					return false
				end
			elsif water_heater_type == "WaterHeater:Stratified"
				heater_1_setpoint_sch_name = water_heater.heater1SetpointTemperatureSchedule.name.get.to_s
				heater_2_setpoint_sch_name = water_heater.heater2SetpointTemperatureSchedule.name.get.to_s
				unless heater_1_setpoint_sch_name == heater_2_setpoint_sch_name
					runner.registerError("Heater setpoint schedules do not match for #{water_heater_type}: #{water_heater.name.get.to_s}")
					return false
				end
				runner.registerValue("setpoint_temperature_schedule", heater_1_setpoint_sch_name)
				runner.registerInfo("Registering #{heater_1_setpoint_sch_name} for setpoint_temperature_schedule")
			end
		else
			heat_pump_setpoint_sch_name = heat_pump.compressorSetpointTemperatureSchedule.name.get.to_s
			runner.registerValue("setpoint_temperature_schedule", heat_pump_setpoint_sch_name)
			runner.registerInfo("Registering #{heat_pump_setpoint_sch_name} for setpoint_temperature_schedule")
		end		
		
		# register use flow rate schedule name
		if water_heater.useFlowRateFractionSchedule.is_initialized
			runner.registerValue("use_flow_rate_fraction_schedule", water_heater.useFlowRateFractionSchedule.get.name.get.to_s)
			runner.registerInfo("Registering #{water_heater.useFlowRateFractionSchedule.get.name.get.to_s} for use_flow_rate_fraction_schedule")
		else
			runner.registerValue("use_flow_rate_fraction_schedule", "NA")
			runner.registerInfo("Registering NA for use_flow_rate_fraction_schedule")
		end
		
		# register ambient temperature indicator
		amb_temp_indicator = water_heater.ambientTemperatureIndicator
		runner.registerValue("ambient_temperature_indicator", amb_temp_indicator)
		runner.registerInfo("Registering #{amb_temp_indicator} for ambient_temperature_indicator")
		
		# register ambient temperature zone
		if amb_temp_indicator == "ThermalZone"
			# register ambient temperature schedule
			runner.registerValue("ambient_temperature_schedule", "NA")
			runner.registerInfo("Registering NA for ambient_temperature_schedule")
			# register ambient temperature zone
			if water_heater.ambientTemperatureThermalZone.is_initialized
				runner.registerValue("ambient_temperature_zone", water_heater.ambientTemperatureThermalZone.get.name.get.to_s)
				runner.registerInfo("Registering #{water_heater.ambientTemperatureThermalZone.get.name.get.to_s} for ambient_temperature_zone")
			else
				runner.registerError("Ambient temperature zone not specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
				return false
			end
		elsif amb_temp_indicator == "Schedule"
			# register ambient temperature zone
			runner.registerValue("ambient_temperature_zone", "NA")
			runner.registerInfo("Registering NA for ambient_temperature_zone")
			# register ambient temperature schedule
			if water_heater.ambientTemperatureSchedule.is_initialized
				runner.registerValue("ambient_temperature_schedule", water_heater.ambientTemperatureSchedule.get.name.get.to_s)
				runner.registerInfo("Registering #{water_heater.ambientTemperatureSchedule.get.name.get.to_s} for ambient_temperature_schedule")
			else
				runner.registerError("Ambient temperature schedule not specified for #{water_heater_type}: #{water_heater.name.get.to_s}")
				return false
			end
		elsif amb_temp_indicator == "Outdoors"
			# register ambient temperature schedule
			runner.registerValue("ambient_temperature_schedule", "NA")
			runner.registerInfo("Registering NA for ambient_temperature_schedule")
			# register ambient temperature zone
			runner.registerValue("ambient_temperature_zone", "NA")
			runner.registerInfo("Registering NA for ambient_temperature_zone")
		else
			runner.registerError("Unexpected ambient temperature indicator (#{amb_temp_indicator}) for #{water_heater_type}: #{water_heater.name.get.to_s}; expecting Zone, Schedule, or Outdoors")
			return false
		end	
    
    return true
  end
end

# register the measure to be used by the application
ReportElectricWaterHeaterInformation.new.registerWithApplication
