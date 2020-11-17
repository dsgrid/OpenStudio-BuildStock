# insert your copyright here

# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/reference/measure_writing_guide/

require 'erb'
# load OpenStudio measure libraries from openstudio-extension gem
require 'openstudio-extension'
require 'openstudio/extension/core/os_lib_helper_methods'

# start the measure
class ReportMeasureOutput < OpenStudio::Measure::ReportingMeasure

# resource file modules
include OsLib_HelperMethods

  # human readable name
  def name
    # Measure name should be the title case of the class name.
    return 'ReportMeasureOutput'
  end

  # human readable description
  def description
    return 'Gets values registered in other measures and reports them (buildstockbatch only pulls values from reporting measures and a few core measures).  Need to call values by name.'
  end

  # human readable description of modeling approach
  def modeler_description
    return 'Gets values registered in other measures and reports them (buildstockbatch only pulls values from reporting measures and a few core measures).  Need to call values by name.'
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
      "event_start_time",
      "event_end_time"
    ]
    string_properties = [
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

    # # get the last model and sql file
    # model = runner.lastOpenStudioModel
    # if model.empty?
      # runner.registerError('Cannot find last model.')
      # return false
    # end
    # model = model.get

    # # sql_file = runner.lastEnergyPlusSqlFile
    # if sql_file.empty?
      # runner.registerError('Cannot find last sql file.')
      # return false
    # end
    # sql_file = sql_file.get
    # model.setSqlFile(sql_file)

		# get values
		event_start_time = OsLib_HelperMethods.check_upstream_measure_for_arg(runner, "event_start_time")
		event_end_time = OsLib_HelperMethods.check_upstream_measure_for_arg(runner, "event_end_time")

		# register event start time
		if !event_start_time.empty?
			measure_name = event_start_time[:measure_name]
			value = event_start_time[:value]
			runner.registerInfo("Registering #{value.round(2)} (from measure #{measure_name}) for event_start_time")
			runner.registerValue("event_start_time", value)
		else
			runner.registerInfo("No value found for event_start_time")
		end

		# register event end time
		if !event_end_time.empty?
			measure_name = event_end_time[:measure_name]
			value = event_end_time[:value]
			runner.registerInfo("Registering #{value.round(2)} (from measure #{measure_name}) for event_end_time")
			runner.registerValue("event_end_time", value)
		else
			runner.registerInfo("No value found for event_end_time")
		end

    # close the sql file
    # sql_file.close

    return true
  end
end

# register the measure to be used by the application
ReportMeasureOutput.new.registerWithApplication
