# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'erb'

#start the measure
class ReportCoolingSystemInformation < OpenStudio::Ruleset::ReportingUserScript

  # human readable name
  def name
    return "ReportCoolingSystemInformation"
  end

  # human readable description
  def description
    return "Reporting measure to output relevant cooling system information"
  end

  # human readable description of modeling approach
  def modeler_description
    return "Reporting measure to output relevant cooling system information"
  end

  # define the arguments that the user will input
  def arguments()
    args = OpenStudio::Ruleset::OSArgumentVector.new
    # this measure does not require any user arguments, return an empty list

    return args
  end 
	
  # define the outputs that the measure will create
  def outputs
    result = OpenStudio::Measure::OSOutputVector.new

    numeric_properties = [
			"dx_cooling_nominal_cop",
			"dx_cooling_nominal_capacity",
			"living_room_area_fraction"
    ]
    
    numeric_properties.each do |numeric_property|
      result << OpenStudio::Measure::OSOutput.makeDoubleOutput(numeric_property)
    end

    return result
  end
  
  # return a vector of IdfObject's to request EnergyPlus objects needed by the run method
  def energyPlusOutputRequests(runner, user_arguments)
    super(runner, user_arguments)
    
    result = OpenStudio::IdfObjectVector.new
    
    # use the built-in error checking 
    if !runner.validateUserArguments(arguments(), user_arguments)
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
		
		# get cooling coil(s)
		cooling_coils = model.getCoilCoolingDXSingleSpeeds
		
		if cooling_coils.length == 0
      runner.registerAsNotApplicable("Number of CoilCoolingDXSingleSpeed objects is #{cooling_coils.length}; measure is not applicable")
      return true
		end	
		
		# get conditioned thermal zones
		living_room_zone = false
		finished_basement_zone = false
		
		model.getThermalZones.each do |zone|
			zone_name = zone.name.get.to_s
			if zone_name == "living zone"
				living_room_zone = zone
			elsif zone_name == "finished basement zone"
				finished_basement_zone = zone
			end	
		end
		
		if finished_basement_zone
			# calculate zone area fractions
			total_area = 0
			living_room_area = 0
			living_room_area_fraction = 0
			living_room_zone.spaces.each do |space|
				living_room_area += space.floorArea
				total_area += space.floorArea
			end
			finished_basement_zone.spaces.each do |space|
				total_area += space.floorArea
			end
			living_room_area_fraction = living_room_area / total_area
		else
			living_room_area_fraction = 1
		end	
		
		runner.registerValue("living_room_area_fraction", living_room_area_fraction)
		runner.registerInfo("Registering #{living_room_area_fraction} for living_room_area_fraction")
		
		cooling_coil_hash = {}
		total_cooling_capacity = 0
		capacity_weighted_cop = 0
		
		cooling_coils.each do |cooling_coil|
			# create hash entry
			cooling_coil_name = cooling_coil.name.get.to_s
			cooling_coil_hash[cooling_coil_name] = {}
			# get coil nominal COP
			if cooling_coil.ratedCOP.is_initialized
				cooling_coil_hash[cooling_coil_name]["COP"] = cooling_coil.ratedCOP.get
			else
				runner.registerError("Rated COP not specified for Single Speed DX Coil: #{cooling_coil_name}")
				return false
			end
			# get coil nominal capacity
			if cooling_coil.ratedTotalCoolingCapacity.is_initialized
				cooling_coil_hash[cooling_coil_name]["Capacity"] = cooling_coil.ratedTotalCoolingCapacity.get
			else
				runner.registerError("Nominal capacity not specified for Single Speed DX Coil: #{cooling_coil.name.get.to_s}")
				return false
			end
		end
		
		# calculate total capacity and capacity-weighted COP
		cooling_coil_hash.keys.each do |cooling_coil_name|
			total_cooling_capacity += cooling_coil_hash[cooling_coil_name]["Capacity"]
			capacity_weighted_cop += cooling_coil_hash[cooling_coil_name]["COP"] * cooling_coil_hash[cooling_coil_name]["Capacity"]
		end
		capacity_weighted_cop = capacity_weighted_cop / total_cooling_capacity
		
		# register capacity-weighted cop
		runner.registerValue("dx_cooling_nominal_cop", capacity_weighted_cop)
		runner.registerInfo("Registering #{capacity_weighted_cop.round(2)} for dx_cooling_nominal_cop")
		
		# register total capacity
		runner.registerValue("dx_cooling_nominal_capacity", total_cooling_capacity)
		runner.registerInfo("Registering #{total_cooling_capacity.round(2)} for dx_cooling_nominal_capacity")
    
    return true
 
  end

end

# register the measure to be used by the application
ReportCoolingSystemInformation.new.registerWithApplication
