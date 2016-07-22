# coverage_binner

Used to bin base-by-base coverage data from Picard HSMetrics. The binned output is then used in the design of rebalanced SureSelect tNGS panels (Ellard, S., Allen, H.L., De Franco, E., Flanagan, S.E., Hysenaj, G., Colclough, K., Houghton, J.A.L., Shepherd, M., Hattersley, A.T., Weedon, M.N. and Caswell, R., 2013. Improved genetic testing for monogenic diabetes using targeted next-generation sequencing. Diabetologia, 56(9), pp.1958-1963. http://www.ncbi.nlm.nih.gov/pmc/articles/PMC3737433/).

Default bin_size is 10 bases

At the moment there are alot of hard-coded paths, which need to be moved out to a config file.
