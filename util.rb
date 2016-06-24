require 'optparse'
require 'csv'

def get_analysis_from_excel(filename)
    require 'openstudio-analysis'
    analyses = OpenStudio::Analysis.from_excel(filename)
    return analyses.first
end

def get_existing_csv_path_from_analysis(analysis)
    existing_csv = nil
    analysis.libraries.files.each do |file|
        next if file[:metadata][:library_name] != "existing_results"
        existing_csv = file[:file]
    end
    if existing_csv.nil?
        puts "ERROR: Could not determine existing csv file."
        exit
    end
    return existing_csv
end

def get_number_of_samples_from_analysis(analysis)
    return analysis.algorithm['number_of_samples']
end

def get_probability_distribution_files_from_analysis(analysis, resources_dir, dirname)
    files = []
    analysis.workflow.measures.each do |measure|
        next if measure.measure_definition_class_name != 'CallMetaMeasure'
        dir = measure.measure_definition_directory
        measure.arguments.each do |argument|
            next if argument[:name] != 'probability_file'
            files << File.join(resources_dir, 'inputs', dirname, argument[:default_value])
        end
    end
    if files.size == 0
        puts "ERROR: Could not find probability distribution filenames."
        exit
    end
    return files
end

def get_combination_hashes(parameter_option_names, dependencies)
    combos_hashes = []

    # Construct array of dependency value arrays
    depval_array = []
    dependencies.each do |dep|
        depval_array << parameter_option_names[dep]
    end
    
    if depval_array.size == 0
        return combos_hashes
    end
    
    # Create combinations
    combos = depval_array.first.product(*depval_array[1..-1])
    
    # Convert to combinations of hashes
    combos.each do |combo|
        # Convert to hash
        combo_hash = {}
        if combo.is_a?(String)
            combo_hash[dependencies[0]] = combo
        else
            dependencies.each_with_index do |dep, i|
                combo_hash[dep] = combo[i]
            end
        end
        combos_hashes << combo_hash
    end
    return combos_hashes
end

def get_num_models(resstock_csv)
    max_model_num = -1
    CSV.read(resstock_csv).each do |row|
        model_num = row[0].sub("LHS Autogenerated ", "").to_i
        next if model_num <= max_model_num
        max_model_num = model_num
    end
    return max_model_num
end

def perform_integrity_checks(project_file, dirname, is_upgrades)
    resources_dir = File.join(File.dirname(__FILE__), 'resources')
    require File.join(resources_dir, 'helper_methods')

    check_file_exists(project_file)
    analysis = get_analysis_from_excel(project_file)
    
    if not is_upgrades
        pdfiles = get_probability_distribution_files_from_analysis(analysis, resources_dir, dirname)
        lookup_file = File.join(resources_dir, 'options_lookup.txt')
        check_file_exists(lookup_file, nil)
      
        # Perform various checks on each probability distribution file
        parameters_processed = []
        option_names = {}
      
        pdfiles.each do |pdfile|
            parameter_name = File.basename(pdfile, File.extname(pdfile))
        
            puts "Checking for issues with #{File.basename(pdfile)}..."
            check_file_exists(pdfile, nil)
            rows, option_names[parameter_name], dependency_cols, header = get_probability_file_data(pdfile, nil)
        
            # Check all dependencies have already been processed
            dependency_cols.keys.each do |dep|
                next if parameters_processed.include?(dep)
                puts "ERROR: #{File.basename(pdfile)} has a dependency '#{dep}' that was not found."
                exit
            end
            parameters_processed << parameter_name
        
            # Test all possible combinations of dependency value combinations
            combo_hashes = get_combination_hashes(option_names, dependency_cols.keys)
            combo_hashes.each do |combo_hash|
                option_name, matched_row_num = get_option_name_from_sample_number(1.0, combo_hash, pdfile, dependency_cols, option_names[parameter_name], rows, nil)
                rows.delete_at(matched_row_num) # speed up subsequent combo_hash searches
            end
        
            # Checks for option_lookup.txt
            measure_args_from_xml = {}
            option_names[parameter_name].each do |option_name|
                # Check for (parameter, option) names
                measure_args = get_measure_args_from_option_name(lookup_file, option_name, parameter_name, nil)
                # Check that measures exist and all measure arguments are provided
                measure_args.keys.each do |measure_subdir|
                    if not measure_args_from_xml.keys.include?(measure_subdir)
                        measurerb_path = File.absolute_path(File.join(File.dirname(lookup_file), 'measures', measure_subdir, "measure.rb"))
                        check_file_exists(measurerb_path, nil)
                        measure_args_from_xml[measure_subdir] = get_measure_args_from_xml(measurerb_path.sub(".rb",".xml"))
                    end
                    validate_measure_args(measure_args_from_xml[measure_subdir], measure_args[measure_subdir].keys, lookup_file, parameter_name, option_name, nil)
                end
            end
        end
    
    else # is_upgrades
        existing_csv = File.join(get_existing_csv_path_from_analysis(analysis), "resstock.csv")
        check_file_exists(existing_csv)
        num_samples = get_number_of_samples_from_analysis(analysis)
        num_models = get_num_models(existing_csv)
        if num_samples != num_models
            puts "ERROR: Number of samples specified in #{File.basename(project_file)} (#{num_samples.to_s}) does not match number of models found in #{File.basename(existing_csv)} (#{num_models.to_s})."
            exit
        end
    end
    
    # If we got this far...
    puts "ALL INTEGRITY CHECKS PASSED."
    
    return pdfiles
end

def generate_parameter_order_file(output_csv, pdfiles)
    text = ""
    pdfiles.each do |pdfile|
        text << "#{File.basename(pdfile, File.extname(pdfile))},"
    end
    File.write(output_csv, text.chomp(','))
end

def run(project_type, caller_rb)

    if project_type != "existing" and project_type != "upgrades"
        puts "ERROR: project_type must be 'existing' or 'upgrades'."
    end

    # Initialize optionsParser ARGV hash
    options = {}

    # Define allowed ARGV input
    optparse = OptionParser.new do |opts|
        opts.banner = "Usage:    ruby #{caller_rb} [-t] <target> [-m] <mode> [-k] [-n]"

        options[:target] = 'aws'
        opts.on( '-t', '--target <target_alias>', 'target OpenStudio-Server instance') do |server|
            options[:target] = server
        end

        options[:rsmode] = 'national'
        opts.on('-m', '--mode <mode>', 'national|pnw') do |mode_type|
            options[:rsmode] = mode_type
        end

        options[:checkonly] = false
        opts.on('-k', '--checkonly', 'check for issues only, don\'t run simulations') do
            options[:checkonly] = true
        end

        options[:nocsv] = false
        opts.on('-n', '--nocsv', 'don\'t download csv results and metadata files') do
            options[:nocsv] = true
        end

        options[:analysis_wait] = 180000 # 50 hrs
        opts.on('--analysis-wait <INTEGER>', 'seconds to wait for job to complete before timeout') do |analysis_wait|
            options[:analysis_wait] = analysis_wait.to_i
        end
        
        opts.on_tail('-h', '--help', 'display help') do
            puts opts
            exit
        end

    end

    # Execute ARGV parsing into options hash holding sybolized key values
    optparse.parse!

    is_upgrades = false
    if project_type == "upgrades"
        is_upgrades = true
    end

    # Get project file associated with mode
    if options[:rsmode] != 'national' and options[:rsmode] != 'pnw'
        fail "ERROR: mode must be 'national' or 'pnw'."
    end
    project_file = nil
    if options[:rsmode] == 'national'
        if is_upgrades
            project_file = File.join(File.dirname(__FILE__),'projects', 'res_stock_national_upgrades.xlsx')
        else
            project_file = File.join(File.dirname(__FILE__),'projects', 'res_stock_national_existing.xlsx')
        end
    elsif options[:rsmode] == 'pnw'
        if is_upgrades
            project_file = File.join(File.dirname(__FILE__),'projects', 'res_stock_pnw_upgrades.xlsx')
        else
            project_file = File.join(File.dirname(__FILE__),'projects', 'res_stock_pnw_existing.xlsx')
        end
    end
    
    results_path = File.join(File.dirname(__FILE__), "results", options[:rsmode])
    if not Dir.exists?(results_path)
        require 'fileutils'
        FileUtils.mkdir_p(results_path)
    end

    # Perform various checks to look for problems
    pdfiles = perform_integrity_checks(project_file, options[:rsmode], is_upgrades)
    
    if not options[:checkonly]
        # Generate order of parameters called for existing buildings; will be reused by upgrade runs
        # to rebuild up the model.
        if not is_upgrades
            generate_parameter_order_file(File.join(results_path, 'resstock_order.csv'), pdfiles)
        end

        # Call cli.rb with appropriate args
        c_arg = '-c'
        if options[:nocsv]
            c_arg = ''
        end
        wait_arg = "--analysis-wait #{options[:analysis_wait].to_s}"
        Kernel.exec("bundle exec ruby cli.rb -t #{options[:target].to_s} -p '#{project_file}' #{wait_arg} #{c_arg} -d #{results_path}")
    end

end