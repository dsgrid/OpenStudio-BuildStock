# see the URL below for information on how to write OpenStudio measures
# http://nrel.github.io/OpenStudio-user-documentation/measures/measure_writing_guide/

require 'csv'

# start the measure
class BuildExistingModel < OpenStudio::Ruleset::ModelUserScript

  # human readable name
  def name
    return "Build Existing Model"
  end

  # human readable description
  def description
    return "Builds the OpenStudio Model for an existing building."
  end

  # human readable description of modeling approach
  def modeler_description
    return "Builds the OpenStudio Model using the sampling csv file, which contains the specified parameters for each existing building. Based on the supplied building number, those parameters are used to run the OpenStudio measures with appropriate arguments and build up the OpenStudio model."
  end

  # define the arguments that the user will input
  def arguments(model)
    args = OpenStudio::Ruleset::OSArgumentVector.new

    # FIXME: Change to integer_sequence
    building_id = OpenStudio::Ruleset::OSArgument.makeIntegerArgument("building_id", true)
    building_id.setDisplayName("Building ID")
    building_id.setDescription("The building number (between 1 and the number of samples).")
    args << building_id
    
    return args
  end

  # define what happens when the measure is run
  def run(model, runner, user_arguments)
    super(model, runner, user_arguments)

    # use the built-in error checking
    if !runner.validateUserArguments(arguments(model), user_arguments)
      return false
    end
    
    building_id = runner.getIntegerArgumentValue("building_id",user_arguments)
    
    # Get file/dir paths
    resources_dir = File.absolute_path(File.join(File.dirname(__FILE__), "..", "..", "lib", "resources")) # Should have been uploaded per 'Other Library Files' in analysis spreadsheet
    helper_methods_file = File.join(resources_dir, "helper_methods.rb")
    measures_dir = File.join(resources_dir, "measures")
    lookup_file = File.join(resources_dir, "options_lookup.tsv")
    resstock_csv = File.absolute_path(File.join(File.dirname(__FILE__), "..", "..", "lib", "worker_initialize", "resstock.csv")) # Should have been generated by the Worker Initialization Script (run_sampling.rb)
    
    # Load helper_methods
    require File.join(File.dirname(helper_methods_file), File.basename(helper_methods_file, File.extname(helper_methods_file)))

    # Check file/dir paths exist
    check_dir_exists(measures_dir, runner)
    check_file_exists(lookup_file, runner)
    check_file_exists(resstock_csv, runner)

    # Retrieve all data associated with sample number
    building_col_name = "Building"
    bldg_data = get_data_for_sample(resstock_csv, building_id, runner, building_col_name)
    register_value(runner, "Building ID", building_id)
    
    # Retrieve order of parameters to run
    parameters_ordered = get_parameters_ordered(resstock_csv)

    # Call each measure for sample to build up model
    parameters_ordered.each do |parameter_name|
        next if parameter_name == building_col_name
    
        # Get measure name and arguments associated with the option name
        option_name = bldg_data[parameter_name]
        register_value(runner, parameter_name, option_name)
        measure_args = get_measure_args_from_option_name(lookup_file, option_name, parameter_name, runner)
        
        measure_args.keys.each do |measure_subdir|
            # Gather measure arguments and call measure
            full_measure_path = File.join(measures_dir, measure_subdir, "measure.rb")
            check_file_exists(full_measure_path, runner)
            
            measure = get_measure_instance(full_measure_path)
            argument_map = get_argument_map(model, measure, measure_args[measure_subdir], lookup_file, parameter_name, option_name, runner)
            print_info(measure_args[measure_subdir], measure_subdir, option_name, runner)

            if not run_measure(model, measure, argument_map, runner)
                return false
            end
        end
        
        if measure_args.empty?
            print_info(nil, nil, option_name, runner)
        end
    end
    
    return true

  end
  
  def get_data_for_sample(resstock_csv, building_id, runner, building_col_name)
    CSV.foreach(resstock_csv, headers:true) do |sample|
        next if sample[building_col_name].to_i != building_id
        return sample
    end
    # If we got this far, couldn't find the sample #
    msg = "Could not find row for #{building_id.to_s} in #{File.basename(resstock_csv).to_s}."
    runner.registerError(msg)
    fail msg
  end
  
  def get_parameters_ordered(resstock_csv)
    return CSV.open(resstock_csv, 'r') { |csv| csv.first }
  end
  
end

# register the measure to be used by the application
BuildExistingModel.new.registerWithApplication
