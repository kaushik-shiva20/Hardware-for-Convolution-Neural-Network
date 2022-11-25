Microarchitecture
![diagram-Copy of System_Design_new drawio_1-1](https://user-images.githubusercontent.com/64697793/203881348-a2347c1e-968a-4c39-b5fe-d28d27c16863.png)


# ECE564 Final Project
This document contains the instructions and commands to setup ECE564 final project directory. In the folder tree of this project, several ```Makefile```s are used to 

## Overview
- [Start Designing](#start-designing)
- [Synthesis](#synthesis)
- [Appendix](#appendix)

## Start Designing
### Setup script

```setup.sh``` is provided to load Modelsim and Synopsys

To source the script:
```bash
source setup.sh
```
This script also enables you to <kbd>Tab</kbd> complete ```make``` commands

### Project description

The document is located in ```project_specification/```

### Where to put your design

A Verilog file ```rtl/dut.v``` is provided with all the ports already connected to the test fixture

### How to compile your design

To compile your design

Change directory to ```run/``` 

```bash
make vlog-v
```

All the .v files in ```rtl/``` will be compiled with this command.

### How to run your design

#### For ECE564
Run with Modelsim UI Base:
```bash
make debug-564-base
```
Run without UI(Faster) Base:
```bash
make verify-564-base
```

### How to compile and run the golden model
In case you still have doubt in how to interface with the test fixture, a golden model is provided for your reference.

To compile the golden model, change directory to ```run/```

```bash
make vlog-golden
```
The run commands are the same ```make debug-564``` for 564 project

Make sure to recompile your own design with the following command when you wish to switch back
```bash
make vlog-v
```
The golden model is only intended to give you an example of how to interface with the SRAMs
and is not synthesizable by design. 

## Synthesis

Once you have a functional design, you can synthesize it in ```synthesis/```

### Synthesis Command
The following command will synthesize your design with a default clock period of 10 ns
```bash
make all
```
### Clock Period

To run synthesis with a different clock period
```bash
make all CLOCK_PER=<YOUR_CLOCK_PERIOD>
```
For example, the following command will set the target clock period to 4 ns.

```bash
make all CLOCK_PER=4
```

### Synthesis Reports
You can find your timing report and area report in ```synthesis/reports/```

## Appendix

### Directory Rundown

You will find the following directories in ```projectFall2022/```

* ```564/``` 
  * Contains the .dat files for the input SRAMs used in 564 project
* ```golden_model/``` 
  * Contains the reference behavior model for the project
  * The content in this directory is compiled instead when executing ```make vlog-golden``` in ```projectFall2022/run/```
* ```inputs/```
  * Contains the .yaml files used to generate the .dat files for all projects
* ```outputs/```
  * Contains the reference output files that can be used for debug
* ```project_report/```
  * Place your project report here before running ```make zip MY_UID=<your_unity_id>``` command
* ```project_specification/```
  * Contains the project specification document
* ```rtl/```
  * All .v files will be compiled when executing ```make vlog-v``` in ```projectFall2022/run/```
  * A template ```dut.v``` that interfaces with the test fixture is provided
* ```run/```
  * Contains the ```Makefile``` to compile and simulate the design
* ```scripts/```
  * Contains the python script that generates the reference output
* ```synthesis/```
  * The directory you will use to synthesize your design
  * Synthesis reports will be exported to ```synthesis/reports/```
  * Synthesized netlist will be generated to ```synthesis/gl/```
* ```testbench/```
  * Contains the test fixture of the project


