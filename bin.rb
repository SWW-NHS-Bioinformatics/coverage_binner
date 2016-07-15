class Bin

	attr_accessor :chromosome, :genomic_start, :genomic_end, :coverage_average, :length_of_bin, :interval_name, :coverage_store

	def calculate_average_coverage()
		  sub_total = 0
			self.coverage_store.each do |this_coverage|
				sub_total += this_coverage.coverage_depth.to_i
			end
			bin_size = self.coverage_store.length.to_i
			if sub_total == 0
				self.coverage_average = sub_total
			else
				self.coverage_average = (sub_total / bin_size)
			end
	end
	
end
