
proc report_dsp_equation {dsp_cell_name args} {

	global verbose
	if {[llength $args] > 0} {
		if {[lsearch -exact $args "-verbose"] >= 0} {
			set verbose 1
		} else {
			set verbose 0
		}
	} else {
		set verbose 0
	}

		# check dsp cell name
	if { [string match DSP48E2 [get_property REF_NAME [get_cells $dsp_cell_name]]] } {

		# set equation [get_alu_equation $w $x $y $z $cin $alumode]
		set equation [get_alu_equation $dsp_cell_name]
		puts "$dsp_cell_name : $equation"

	# bad dsp cell name
	} else {
		puts "That cell name doesn't belong to a DSP."
	}
}

proc get_mult_equation {dsp_cell_name} {
	# get inmode
	global verbose
	set inmode [get_port_connection $dsp_cell_name "INMODE"]
	if {$verbose == 1} {
		puts "INMODE: $inmode"
	}

	set inmode0 [string range $inmode 4 4]
	set inmode1 [string range $inmode 3 3]
	set inmode2 [string range $inmode 2 2]
	set inmode3 [string range $inmode 1 1]
	set inmode4 [string range $inmode 0 0]

	# inmode[1]a/b (selected by PREADDINSEL) can be used to gate the A/B datapaths
	set preaddinsel [get_property PREADDINSEL [get_cells $dsp_cell_name]]

	if {$preaddinsel == "A"} {
		set inmode1a $inmode1
		set inmode1b 0
	} else {
		set inmode1a 0
		set inmode1b $inmode1
	}

	# is A path gated
	if {$inmode1a == 1} {
		set a2a1 0
	} else {
		# determine A2/A1 datapath input pipeline selections
		set areg [get_property AREG [get_cells $dsp_cell_name]]
		if {$inmode0 == 1} {
			set a2a1 "A1"
		} else {
			switch $areg 0 {
				set a2a1 "A0"
			} 1 {
				set a2a1 "A2"
			} 2 {
				set a2a1 "A''"
			}
		}
	}

	# is B path gated
	if {$inmode1b == 1} {
		set $b2b1 0
	} else {
		# determine B2/B1 datapath input pipeline selections
		set breg [get_property BREG [get_cells $dsp_cell_name]] 
		if {$inmode4 == 1} {
			set b2b1 "B1"
		} else {
			switch $breg 0 {
				set b2b1 "B0"
			} 1 {
				set b2b1 "B2"
			} 2 {
				set b2b1 "B''"
			}
		}
	}

	# get multiplier A input
	set amultsel [get_property AMULTSEL [get_cells $dsp_cell_name]]

	# select A pipeline data or pre-adder data
	if {$amultsel == "A"} {
		# A pipeline datapath selected
		set mult_data_a $a2a1
	} elseif {$amultsel == "AD"} {
		# pre-adder path selected

		# determine D input pipeline stages selected
		if {[get_property DREG [get_cells $dsp_cell_name]] == 0} {
			set d_data "D0"
		} else {
			set d_data "D1"
		}

		# is D path gated
		if {$inmode2 == 0} {
			set preadd_d 0
		} else {
			set preadd_d $d_data
		}

		# pre-add input selection
		if {$preaddinsel == "A"} {
			set preadd_ab $a2a1
		} else {
			set preadd_ab $b2b1
		}

		if {$inmode3 == 1} {
			set preadd "($preadd_d - $preadd_ab)"
		} else {
			set preadd "($preadd_d + $preadd_ab)"
		}

		# determine preadder output pipeline stages
		if {[get_property ADREG [get_cells $dsp_cell_name]] == 0} {
			set ad_data $preadd
		} else {
			set ad_data "$preadd'"
		}

		set mult_data_a $ad_data
	} else {
		puts "unknown value $amultsel returned for $dsp_cell_name"
		return -1
	}


	set bmultsel [get_property BMULTSEL [get_cells $dsp_cell_name]]

	# select B pipeline data or pre-adder data
	if {$bmultsel == "B"} {
		set mult_data_b $b2b1
	} elseif {bmultsel == "AD"} {
		set mult_data_b $ad_data
	} else {
		puts "unknown value $bmultsel returned for $dsp_cell_name"
	}

	if {$verbose == 1} {
		puts "MULT_DATA_A: $mult_data_a"
		puts "MULT_DATA_B: $mult_data_b"
	}

	set mreg [get_property MREG [get_cells $dsp_cell_name]]
	if {$mreg == 1} {
		return "($mult_data_a x $mult_data_b)'"
	} else {
		return "($mult_data_a x $mult_data_b)"
	}
}

# Return DSP external port connection as binary string. Expects the port connection 
# to be harcoded.
proc get_port_connection {dsp_cell_name port_name} {
	set port_connection "" 
	set port_width [llength [get_pins "$dsp_cell_name/$port_name"]]

	if {$port_width > 0} {
		if {$port_width == 1} {
			set net [get_nets -of_objects [get_pins "$dsp_cell_name/$port_name"]]
			if { [regexp const0 $net] } {
				return 0
			} elseif { [regexp const1 $net] } {
				return 1
			} else {
				puts "$port_name is hooked up to a non-static net. I don't know how to handle that."
				return -1
			}
			return $net
		} else {
			for {set pin 0} {$pin < $port_width} {incr pin} {
				# get port pin net connections
				set net [get_nets -of_objects [get_pins "$dsp_cell_name/$port_name\[$pin\]"]]
				# extract 1 or 0 from string netname
				if { [regexp const0 $net] } {
					set port_connection [concat 0$port_connection]
				} elseif { [regexp const1 $net] } {
					set port_connection [concat 1$port_connection]
				} else {
					puts "That port's hooked up to a non-static net. I don't know how to handle that."
					return -1
				}
			}
		}
		return $port_connection
	} else {
		puts "Something went wrong getting $port_name port width."
		return -1
	}
}

proc get_wmux {dsp_cell_name opmode} {
	set wsel [string range $opmode 0 1]

	global verbose

	# determine W mux configuration
	switch $wsel 00 {
		set wmux "0"
	} 01 {
		set preg [get_property PREG [get_cells $dsp_cell_name]]
		set wmux "P$preg"
	} 10 {
		set rnd [get_property RND [get_cells $dsp_cell_name]]
		set wmux "RND: $rnd"
	} 11 {
		set creg [get_property CREG [get_cells $dsp_cell_name]]
		set wmux "C$creg"
	}
	if {$verbose == 1} {
		puts "W mux setting: $wmux"
	}
	return $wmux
}

proc get_xmux {dsp_cell_name opmode} {

	set xsel [string range $opmode 7 8]

	global verbose
	
	# determine X mux configuration
	switch $xsel 00 {
		set xmux "0"
	} 01 {
		set mreg [get_property MREG [get_cells $dsp_cell_name]]
		set xmux "M$mreg"
	} 10 {
		set preg [get_property PREG [get_cells $dsp_cell_name]]
		set xmux "P$preg"
	} 11 {
		set areg [get_property AREG [get_cells $dsp_cell_name]]
		switch $areg 0 {
			set a "A0"
		} 1 {
			set a "A2"
		} 2 {
			set a "A''"
		}
		set breg [get_property BREG [get_cells $dsp_cell_name]]
		switch $breg 0 {
			set b "B0"
		} 1 {
			set b "B2"
		} 2 {
			set b "B''"
		}
		set xmux "$a:$b"
	}
	if {$verbose == 1} {
		puts "X mux setting: $xmux" 
	}
	return $xmux
}

proc get_ymux {dsp_cell_name opmode} {
	set ysel [string range $opmode 5 6]

	global verbose

	# determine Y mux configuration
	switch $ysel 00 {
		set ymux "0"
	} 01 {
		set mreg [get_property MREG [get_cells $dsp_cell_name]]
		set ymux "M$mreg"
	} 10 {
		set ymux "48'hFFFFFFFFFFFF"
	} 11 {
		set creg [get_property CREG [get_cells $dsp_cell_name]]
		set ymux "C$creg"
	}
	if {$verbose == 1} {
		puts "Y mux setting: $ymux" 
	}
	return $ymux
}

proc get_zmux {dsp_cell_name opmode} {
	
	set zsel [string range $opmode 2 4]

	global verbose

	# determine Z mux configuration
	switch $zsel 000 {
		set zmux "0"
	} 001 {
		set pcin [get_port_connection $dsp_cell_name "PCIN"]
		set zmux "PCIN: $pcin"
	} 010 {
		set preg [get_property PREG [get_cells $dsp_cell_name]]
		set zmux "P$preg"
	} 011 {
		set creg [get_property CREG [get_cells $dsp_cell_name]]
		set zmux "C$creg"
	} 100 {
		set preg [get_property PREG [get_cells $dsp_cell_name]]
		set zmux "P$preg"
	} 101 {
		set pcin [get_port_connection $dsp_cell_name "PCIN"]
		set zmux "(PCIN: $pcin << 17)"
	} 110 {
		set preg [get_property PREG [get_cells $dsp_cell_name]]
		set zmux "(P$preg << 17)"
	} 111 {
		set zmux "xx"
	}
	if {$verbose == 1} {
		puts "Z mux setting $zmux"
	}
	return $zmux
}

proc get_cinmux {dsp_cell_name} {

	set cinsel [get_port_connection $dsp_cell_name "CARRYINSEL"]
	global verbose
	if {$verbose == 1} {
		puts "CARRYINSEL: $cinsel"
	}
	
	switch $cinsel 000 {
		set cin_setting "CARRYIN"
		set cin_connection [get_port_connection $dsp_cell_name "CARRYIN"]
	} 001 {
		set cin_setting "~PCIN\[47\]"
		set cin_connection ![get_port_connection $dsp_cell_name "PCIN[47]"]
	} 010 {
		set cin_setting "CARRYCASCIN"
		set cin_connection [get_port_connection $dsp_cell_name "CARRYCASCIN"]
	} 011 {
		set cin_setting "PCIN\[47\]"
		set cin_connection [get_port_connection $dsp_cell_name "PCIN[47]"]
	} 100 {
		set cin_setting "CARRYCASCOUT"
		set cin_connection [get_port_connection $dsp_cell_name "CARRYCASCOUT"]
	} 101 {
		set cin_setting "~P\[47\]"
		set cin_connection ![get_port_connection $dsp_cell_name "P[47]"]
	} 110 {
		set cin_setting "A\[26\] XNOR B\[17\]"
		set a [get_port_connection $dsp_cell_name "A[26]"]
		set b [get_port_connection $dsp_cell_name "B[17]"]
		set cin_connection "($a XOR $b)"
	} 111 {
		set cin_setting "P[47]"
		set cin_connection [get_port_connection $dsp_cell_name "P[47]"]
	}
	if {$verbose == 1} {
		puts "CINmux setting: $cin_setting ($cin_connection)"
	}
	return $cin_connection
}

proc get_alu_equation {dsp_cell_name} {

	# get control inputs
	set opmode [get_port_connection $dsp_cell_name "OPMODE"]
	set alumode [get_port_connection $dsp_cell_name "ALUMODE"]

	global verbose

	if {$verbose == 1} {
		puts "OPMODE: $opmode"
		puts "ALUMODE: $alumode"
	}

	# decode multiplexer outputs
	set w [get_wmux $dsp_cell_name $opmode]
	set x [get_xmux $dsp_cell_name $opmode]
	set y [get_ymux $dsp_cell_name $opmode]
	set z [get_zmux $dsp_cell_name $opmode]
	set cin [get_cinmux $dsp_cell_name]

	set alumode_lsb [string range $alumode 2 3]
	set alumode_msb [string range $alumode 0 1]

	if {$alumode_msb == 00} {

		# handle x/y mux outputs
		if {[string range $y 0 0] == "M"} {
			set xy [get_mult_equation $dsp_cell_name]
		} else {
			set xy "$x + $y"
		}

		switch $alumode_lsb 00 {
			if {$verbose == 1} {
				puts "ALUMODE($alumode) selects Z+W+X+Y+CIN"
			}
			set eq "$z + $w + $xy + $cin"
		} 01 {
			if {$verbose == 1} {
				puts "ALUMODE($alumode) selects -Z+(W+X+Y+CIN)-1"
			}
			set eq "–$z + ($w + $xy + $cin) – 1"
		} 10 {
			if {$verbose == 1} {
				puts "ALUMODE($alumode) selects -Z-W-X-Y-CIN-1"
			}
			set eq "not($z + $w + $xy + $cin)"
		} 11 {
			if {$verbose == 1} {
				puts "ALUMODE($alumode) selects Z-(W+X+Y+CIN)"
			}
			set eq "$z - ($w + $xy + $cin)"
		}
		
		# determine P output pipeline stages
		set preg [get_property PREG [get_cells $dsp_cell_name]]
		if {$preg == 1} {
			set eq "($eq)'"
		}

	} else {
		if {$verbose == 1} {
			puts "ALUMODE selects Two-Input Logic Unit or Three-Input XOR Special Case (TBD, maybe)"
		}
		set eq "TBD"
	}
	return $eq
}