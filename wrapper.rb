class Wrapper
	
		def run_command(cmd, logger)
			#setup IO pipe to collect outputs from new process
			pipe_cmd_in, pipe_cmd_out = IO.pipe
			
			#collect process ID of new process, passing IO pipe as output destination for errors and standard out
			cmd_pid = Process.spawn(cmd, :out => pipe_cmd_out, :err => pipe_cmd_out)
			
			#fire up the logger
			logger.info('Process') { "Spawning process... #{cmd_pid}" }
			
				#wait until new thread finishes
				@exitstatus = :not_done
				Thread.new do
				  Process.wait(cmd_pid); 
				  @exitstatus = $?.exitstatus
				end
			
			pipe_cmd_out.close
			
			out = pipe_cmd_in.read;
			sleep(0.1) while @exitstatus == :not_done
			logger.info('processed') { "#{cmd_pid} child process: Exit status: #{@exitstatus}" }
			if @exitstatus != 0
				logger.info('error') { "#{out.inspect}" }
			end
			return [@exitstatus, out]
		end
end
