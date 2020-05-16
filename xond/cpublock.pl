sub write_cpu_block {
	state @last_idle;
	state @last_total;

	# TODO z could make this state for (slightly) better performance
	my $topo_sockets          = CpuTopology::n_sockets();
	my $topo_cores_per_socket = CpuTopology::n_cores_per_socket();
	my $topo_threads_per_core = CpuTopology::n_threads_per_core();

	my @cpuutil;

	open(my $fh, "/proc/stat");
	while(<$fh>) {
		last unless $_ =~ /^cpu/;
		my @entry = split /\s+/;
		my $cpu = substr(shift @entry, 3);
		my $cpunum = $cpu eq ""? 0: int($cpu) + 1;
	
		my $idle = $entry[3];
		my $total = List::Util::sum(@entry);

		$last_idle[$cpunum]  //= 0;
		$last_total[$cpunum] //= 0;

		my $deltatotal = $total - $last_total[$cpunum];
		$cpuutil[$cpunum] = ($deltatotal - ($idle - $last_idle[$cpunum])
								) / $deltatotal;

		$last_idle[$cpunum]  = $idle;
		$last_total[$cpunum] = $total;
	}
	close($fh);

	my $entry = "C";
	my $curcore = 0;
	my $curthread = 0;
	my $sep = "";
	for(my $i = 1; $i < @cpuutil; $i++) {
		$entry .= $sep.get_gauge_vert($cpuutil[$i]);
		if(++$curthread >= $topo_threads_per_core) {
			$curthread = 0;
			if(++$curcore >= $topo_cores_per_socket) {
				$curcore = 0;
				$sep = "|";
			} else {
				$sep = " ";
			}
		} else {
			$sep = "";
		}
	}

	print($entry."\n");
}
