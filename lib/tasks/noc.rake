# Rake tasks for handling the National Operator Codes spreadsheet
require File.dirname(__FILE__) +  '/data_loader'
namespace :noc do

  include DataLoader

  namespace :pre_load do

    desc "Parses operator contact information and produces output about what would be loaded. Requires a CSV file specified as FILE=filename"
    task :operator_contacts => :environment do
      parser = Parsers::OperatorContactsParser.new
      parser.parse_operator_contacts(ENV['FILE'], dryrun=true)
    end

    desc 'Parses operator contact information from a Traveline format file and produces output about what would be loaded. Requires a CSV file specified as FILE=filename'
    task :traveline_operator_contacts => :environment do
      parser = Parsers::OperatorContactsParser.new
      parser.parse_traveline_operator_contacts(ENV['FILE'], dryrun=true)
    end
  end

  namespace :load do

    desc "Loads operators from a CSV file specified as FILE=filename.
          Runs in dryrun mode unless DRYRUN=0 is specified."
    task :operators => :environment do
      parse(Operator, Parsers::NocParser)
    end

    desc "Loads operator codes in different regions from a CSV file specified as FILE=filename.
          Runs in dryrun mode unless DRYRUN=0 is specified."
    task :operator_codes => :environment do
      parse(OperatorCode, Parsers::NocParser)
    end

    desc "Loads vosa licenses from a CSV file specified as FILE=filename.
          Runs in dryrun mode unless DRYRUN=0 is specified."
    task :vosa_licenses => :environment do
      parse(VosaLicense, Parsers::NocParser)
    end

    desc "Loads operator contact information from a CSV file specified as FILE=filename.
          Runs in dryrun mode unless DRYRUN=0 is specified."
    task :operator_contacts => :environment do
      parse(OperatorContact, Parsers::OperatorContactsParser)
    end

    desc "Loads stop area operator information from a CSV file specified as FILE=filename.
          Runs in dryrun mode unless DRYRUN=0 is specified."
    task :station_operators => :environment do
      parse(StopAreaOperator, Parsers::OperatorsParser)
    end

    desc 'Loads operator contact information from a Traveline format of CSV file specified as FILE=filename.
          Runs in dryrun mode unless DRYRUN=0 is specified.'
    task :traveline_operator_contacts => :environment do
      parse(OperatorContact, Parsers::OperatorContactsParser, 'parse_traveline_operator_contacts')
    end

  end

  namespace :update do

    desc "Updates operators from a TSV file specified as FILE=filename to generation id specified
          as GENERATION=generation. Runs in dryrun mode unless DRYRUN=0 is specified. Verbose flag
          set by VERBOSE=1"
    task :operators => :environment do
       load_instances_in_generation(Operator, Parsers::NocParser)
    end

    desc "Updates operator codes from a TSV file specified as FILE=filename to generation id specified
          as GENERATION=generation. Runs in dryrun mode unless DRYRUN=0 is specified. Verbose flag
          set by VERBOSE=1"
    task :operator_codes => :environment do
      load_instances_in_generation(OperatorCode, Parsers::NocParser)
    end

    desc "Updates vosa licenses from a TSV file specified as FILE=filename to generation id specified
          as GENERATION=generation. Runs in dryrun mode unless DRYRUN=0 is specified. Verbose flag
          set by VERBOSE=1"
    task :vosa_licenses => :environment do
      load_instances_in_generation(VosaLicense, Parsers::NocParser)
    end

  end

end