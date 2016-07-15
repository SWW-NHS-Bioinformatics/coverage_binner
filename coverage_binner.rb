class CoverageBinner
	require 'smarter_csv'
	require 'awesome_print'
  require 'yaml'
  require 'spreadsheet'
  require 'active_support'
  require 'active_support/core_ext'
  require 'parallel'
  require 'logger'
  
  require_relative 'coverage'
  require_relative 'interval'
  require_relative 'wrapper'
  require_relative 'bin'
  require_relative 'batch'

  def load_intervals(interval_file_name)
  	options = { :col_sep => "\t" }
  	interval_array = Array.new
  	  
  	SmarterCSV.process( interval_file_name, options ) do |csv|
  			
  	  	this_interval_line = Interval.new
  	  	this_interval_line.chromosome = csv.first[:chromosome].to_s 	
  	  	this_interval_line.genomic_start = csv.first[:genomic_start].to_s
  	  	this_interval_line.genomic_end = csv.first[:genomic_end].to_s
  	  	this_interval_line.strand = csv.first[:strand].to_s
  	  	this_interval_line.interval_name = csv.first[:interval_name].to_s
  	  	
  	  	interval_array.push(this_interval_line)
  	  	
  	end
  	return interval_array 
  end
  
  def load_coverage(directory_path, sample_id)
  	#set options for smarter csv: tab-delimited
  	#return all file name that match the pattern - deal with gender with a regex
  	this_file_array = Dir["#{directory_path}/#{sample_id}.by_base_coverage"]
  	
  	#Only take the first match - there should only be one but Dir[] will return an array
  	file_name = this_file_array.first
  	
  	options = { :col_sep => "\t" }
  	
  	coverage_array = Array.new
  	coverage_depth = "depth_for_#{sample_id.downcase!}".parameterize

  	puts "#{coverage_depth}"
  	SmarterCSV.process( file_name, options ) do |csv|
  		#puts csv.first.inspect
  	  if csv.first[coverage_depth.to_sym]
  		  this_coverage_line = Coverage.new
  		  this_coverage_line.locus = csv.first[:locus]
  		  this_coverage_line.coverage_depth = csv.first[coverage_depth.to_sym]
  		  this_coverage_line.parse_locus()
  		
  		  coverage_array.push(this_coverage_line)
  	  end
  	end
  	return coverage_array
  end
  
  def parse_intervals(coverage_array, interval_array)
  	completed_coverage_array = Array.new
  	interval_array.each do |this_interval|
  	  coverage_array.each do |this_coverage|
  	  	if (this_coverage.chromosome == this_interval.chromosome) && (this_coverage.genomic_coords.to_i >= this_interval.genomic_start.to_i) && (this_coverage.genomic_coords.to_i <= this_interval.genomic_end.to_i)
  	  		this_coverage.interval_name = this_interval.interval_name
  	  		completed_coverage_array.push(this_coverage)
  	  		#coverage_array.delete(this_coverage)
  	  	end	  
  	  end
  	  #interval_array.delete(this_interval)
  	end
  	return completed_coverage_array
  end
  
  def coverage_to_bins(coverage_array, this_bin, bin_store, this_interval)
  	
  	coverage_array.each do |this_coverage|
  		if (this_bin.genomic_start..this_bin.genomic_end).include?(this_coverage.genomic_coords.to_i)
  			this_bin.interval_name = this_interval.interval_name
  			this_bin.coverage_store.push(this_coverage)
  			#coverage_array.delete(this_coverage) 			
  		end
  	end

  	return this_bin
	end
	
	def generate_bins(bin_store, chromosome, genomic_start, this_quotient, bin_size, this_coverage_binner, coverage_array, this_interval)
	  (1..this_quotient).each do |n|
  			this_bin = Bin.new
  			this_bin.chromosome = chromosome
  			this_bin.genomic_start = genomic_start
  			this_bin.genomic_end = (genomic_start + bin_size)-1
  			this_bin.length_of_bin = bin_size
  			this_bin.coverage_store = Array.new
    		
  			this_bin = this_coverage_binner.coverage_to_bins(coverage_array, this_bin, bin_store, this_interval)
  			this_bin.calculate_average_coverage()
    		
  			genomic_start = this_bin.genomic_end + 1
  			
  			bin_store.push(this_bin)
		end
		return bin_store
	end
	
	def generate_reminder_bins(bin_store, chromosome, genomic_end, this_modulos, this_coverage_binner, coverage_array, this_interval)
		reminder_start = (genomic_end - this_modulos)
		bin_size = 1
		
		(1..this_modulos).each do |n|
  			this_bin = Bin.new
  			this_bin.chromosome = chromosome
  			this_bin.genomic_start = (reminder_start + 1)
  			this_bin.genomic_end = (reminder_start + 1)
  			this_bin.length_of_bin = bin_size
  			this_bin.coverage_store = Array.new
    		
  			this_bin = this_coverage_binner.coverage_to_bins(coverage_array, this_bin, bin_store, this_interval)
  			this_bin.calculate_average_coverage()
    		
  			reminder_start = this_bin.genomic_end
  			
  			bin_store.push(this_bin)
		end
		
		return bin_store
	end
	
	
	def write_sample_worksheet(this_book, results_store, sample_id)
		
  		this_sheet = this_book.create_worksheet :name => "#{sample_id}"

  		  row_count = 0
  		  
  		  this_sheet.row(row_count).push "CHROMOSOME", "GENOMIC_START", "GENOMIC_END", "LENGTH_OF_BIN", "COVERAGE_AVERAGE", "INTERVAL_NAME"
  		  row_count = row_count + 1
  		  results_store.each do |this_result|
  		  	this_result.each do |this_bin|
  		  		#write out to spreadsheet
  		  		this_sheet.row(row_count).push "#{this_bin.chromosome}", "#{this_bin.genomic_start}", "#{this_bin.genomic_end}", "#{this_bin.length_of_bin}", "#{this_bin.coverage_average}", "#{this_bin.interval_name}"
  		  		puts "#{this_bin.chromosome}", "#{this_bin.genomic_start}, #{this_bin.genomic_end}, #{this_bin.length_of_bin}, #{this_bin.coverage_average}, #{this_bin.interval_name}"
  		  		row_count = row_count + 1
  		  	end
 		  		
  		  end
  		
  		return this_book
  		
  end
  
  def calculate_coverage(sample_id, intervals_path, batch, logger)
		
			this_wrapper = Wrapper.new
				
			input_file_string  = "#{batch.base_path}/assembly/#{sample_id}.bam"
			output_file_string = "#{batch.base_path}/coverage/#{sample_id}.by_base_coverage"
		
			cmd = "( #{batch.java_path} -Xmx4g -jar #{batch.gatk_path} -T DepthOfCoverage -L #{intervals_path} -R #{batch.reference_path} -I #{input_file_string} -o #{output_file_string} "
			cmd += "-mmq 30 -mbq 30 -dels -ct 1 -ct 10 -ct 20 -ct 30 -ct 40 -ct 50 -omitLocusTable )"
		  
			output = this_wrapper.run_command(cmd, logger)
			
			return output
	end
	
	def error_check(out, sample_id, stage, logger)
			if out && (out[0] > 0)
				puts "ERROR :: #{stage} :: Halting pipeline at Sample #{sample_id}\n"
				ap "#{out[1].inspect}"
				logger.info('error') { "SAMPLE :: #{sample_id} #{out[1].inspect}" }
				
				raise Parallel::Break
			end
	end
	
  this_coverage_binner = CoverageBinner.new
  this_batch = Batch.new
  
  this_batch.base_path = "/mnt/Data4/working_directory/garan/coverage_binner/v603_targeted_coverage"
  this_batch.java_path = "/usr/share/java-1.8.0/java"
  this_batch.gatk_path = "/usr/share/gatk/GenomeAnalysisTK-3.6.0/GenomeAnalysisTK.jar"
  this_batch.reference_path = "/mnt/Data1/resources/human_g1k_v37.fasta"
  this_batch.intervals_directory = "/mnt/Data4/working_directory/garan/coverage_binner/v603_targeted_coverage/intervals"
  
  this_logger = Logger.new("#{this_batch.base_path}/logs/pipeline.log")
  interval_array = this_coverage_binner.load_intervals("#{this_batch.intervals_directory}/v603_all_covered_bases_v37.tsv")
  intervals_path	=	"#{this_batch.intervals_directory}/v603_all_covered_bases_v37.bed"
  
  #names of samples to be processed forms part of the BAM file name
  samples = ["v603_EX1604684"]
  
  #results = Parallel.map(samples, :in_processes=>12 ) do |this_sample|
  samples.each do |this_sample|
  	
  	out = this_coverage_binner.calculate_coverage(this_sample, intervals_path, this_batch, this_logger)
  	this_coverage_binner.error_check(out, this_sample, "Calculate coverage", this_logger)
  	puts "Running ... #{this_sample}"
  	coverage_array = this_coverage_binner.load_coverage("#{this_batch.base_path}/coverage", "#{this_sample}")
  	
  	bin_size = 10
  	results_store = Array.new
  	interval_array.each do |this_interval|
  		
  		genomic_start = this_interval.genomic_start.to_i
  		genomic_end = this_interval.genomic_end.to_i
  		
  		number_of_bases = (genomic_end + 1) - genomic_start
  		quotient_and_modulos_array = number_of_bases.divmod(bin_size)
  		
  		this_quotient = quotient_and_modulos_array[0].to_i
  		this_modulos = quotient_and_modulos_array[1].to_i
  	
  		bin_store = Array.new
  		bin_store = this_coverage_binner.generate_bins(bin_store, this_interval.chromosome, genomic_start, this_quotient, bin_size, this_coverage_binner, coverage_array, this_interval)
  		bin_store = this_coverage_binner.generate_reminder_bins(bin_store, this_interval.chromosome, genomic_end, this_modulos, this_coverage_binner, coverage_array, this_interval)
  		
  		results_store.push(bin_store)
  		puts "Finished processing ... #{this_sample} ... #{this_interval.interval_name}"
  	end
  	#open('results.yaml', 'w') { |f| YAML.dump(results_store, f) }
  	puts "Writing results ... #{this_sample}"
  	this_book = Spreadsheet::Workbook.new
  	this_book = this_coverage_binner.write_sample_worksheet(this_book, results_store, "#{this_sample}")
  	this_book.write "#{this_batch.base_path}/results/#{this_sample}_coverage.xls"
  end

end
