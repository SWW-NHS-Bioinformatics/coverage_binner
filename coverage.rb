class Coverage

	attr_accessor :coverage_depth, :interval_name
	attr_accessor :chromosome, :genomic_coords
	attr_accessor :locus

	def parse_locus()
		# format for locus is chromosome:genomic_coords - 18:19757092
		tmp_array = self.locus.split(":")
		self.chromosome = tmp_array[0]
		self.genomic_coords = tmp_array[1]
	end
end
