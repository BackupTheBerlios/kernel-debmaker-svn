#!/usr/bin/perl -w

# TODO command line: remove -f and -t options since the parameters are mandatory.
#      => use Getop::Long and Pod::usage();
#      http://perl.active-venture.com/lib/Getopt/Long.html
#      http://www.perldoc.com/perl5.6/pod/perlpod.html
#      http://perl.active-venture.com/lib/Pod/Usage.html
# TODO use GnuPG module to import kernel.org public key.
# TODO use the ~/.kernel-debmaker/config.xml to set tmpdir, etc.
# TODO Handle ketchup dependency (nice way: a package for ketchup)
# TODO License headers!!!!
# TODO Better XML support for kernel.xml (descriptions, define patch as
#      an url, which possibly requires decompression)
# TODO Add a log/kernel-debmaker.log file in the output, with a copy of all of
#      the program's output.
# TODO Move debian specific code in a class. Idea: a class specific to debian
#      which inherits from another abstract class. This would lead to a project
#      name change
# TODO Run it with sudo in order to debug in eclipse?
# TODO examples in man page
# TODO kernel-debmaker -h, --help, -v, --version must work!
# TODO Check ketchup options!!!
# TODO use a specific ketchup cache in ~/.kernel-debmaker
# TODO Test suite
# TODO --verbose option which displays build progress
# TODO GUI to edit kernel.xml
# TODO Changelog editing with "dch"? (dch must be run from within the tree)
# TODO Check that kernel-modules works even if there is no module (default...)
# TODO Handle nice priority in user conf
# TODO more details about each patch in the xml (tricky XML::Simple ...)
# TODO .deb repository on berlios.de webpage
# TODO DTD and validation before loading xml files

use strict;
use warnings;
use diagnostics -verbose;

use Getopt::Std;
use Switch;
use File::Spec;
use POSIX qw(:sys_wait_h);
use IO::Handle;
use XML::Simple qw(:strict);
use Data::Dumper;

my $version = "0.2";

# Say hello!
print "kernel-debmaker $version
Copyright 2003-2004 Olivier Ricordeau (olivier.ricordeau\@wanadoo.fr)
This is free software with ABSOLUTELY NO WARRANTY.\n\n";

# Parse command line options with Getopt::Std.
my %options = ();
getopts("hdc:o:w:f:t:",\%options);

# Print help and exit if -h option.
if (defined $options{h})
{
	print "Builds Debian packages of a kernel using a configuration file.
License: GNU GPL.
Usage:
kernel-debmaker [-h] [-d] [-c config.xml] [-o output_dir]
                [-w work_dir] [-t target] -f kernel.xml
-h: Displays this help message.
-d: Activates debug mode.
-c config.xml: use the specified configuration file.
-o output_dir: use the specified directory to output .deb packages.
-w work_dir: use the specified working directory.
-t target: build the specified target. Default: \"kernel-modules\"
           The available targets are:
           * kernel: builds .deb's of kernel + modules thanks to make-kpkg.
           * modules: builds .deb's of modules using files in /usr/src/modules.
           * kernel-modules: alias for kernel + modules.
           * edit: edit the kernel config file with \"make xconfig\".
           * tarball: create a distributable tarball containing build info.
           * fetch: fetch sources and create a sources tree.
           * clean: clean temporary files.
           * clean-binary: clean temporary files and built packages.
-f kernel.xml: use the specified build configuration file.
";
	exit 0;
}

# Check -d
my $debugMode = 0;
if (defined $options{d})
{
	$debugMode = 1;
}

# Check that the arguments are valid.

# Check -c.
my %buildXmlConfig = ();
#if (defined $options{c})
#{
#	readConfigFile($options{c});
#}
#else
#{
#	if (-f "$ENV{HOME}/.kernel-debmaker/config")
#	{
#		readConfigFile("$ENV{HOME}/.kernel-debmaker/config");
#	}
#	else
#	{
#		`mkdir -p $ENV{HOME}/.kernel-debmaker`;
#		`touch $ENV{HOME}/.kernel-debmaker/config`;
#		print STDERR "Error: please fill the configuration file (default: ~/.kernel-debmaker/config)!\n";
#		exit 1;
#	}
#}

# Check -o.
my $outDir = "";
if (defined $options{o})
{
	if (!(-d $options{o}))
	{
		`mkdir $options{o}`;
	}
	$outDir = $options{o};
}
else
{
	$outDir = "$ENV{HOME}/.kernel-debmaker/output";
}
# Check -w.
my $workDir = "";
if (defined $options{w})
{
	if (!(-d $options{w}))
	{
		`mkdir $options{w}`;
	}
	$workDir = $options{w};
}
else
{
	$workDir = "/tmp";
}

# Check -t.
if (not defined $options{t})
{
	$options{t} = "kernel-modules";
}

# Check -f.
if (not defined $options{f})
{
	print STDERR "Error: no build configuration file provided!\n";
	exit 1;
}
if ( (defined $options{f}) && !(-e $options{f}) )
{
	print STDERR "Error: build configuration file \"$options{f}\" does not exist!\n";
	exit 1;
}

# Set up step counter
my $step = 0;
my $stepCount;

set_step_count();

my $buildXmlConfigDir;
read_build_xml_config();

# Set variables read from the config file.
my $kernelName = $buildXmlConfig{KERNEL_NAME};
my $packageRevision = $buildXmlConfig{PACKAGE_REVISION};
my $kernelVersion = $buildXmlConfig{KERNEL_VERSION};
my $makekpkgOptions = $buildXmlConfig{MAKE_KPKG_OPTIONS};
my $kernelConfigFile = $buildXmlConfig{KERNEL_CONFIG_FILE};

# Set other variables
my $makekpkg = "nice -n 9 make-kpkg -rev Custom.$packageRevision --append_to_version -$kernelName";
my $kernelSources = "linux-$kernelVersion";
my $tarballName = "$kernelVersion-$kernelName.$packageRevision";

# Get output directory's canonical path
my ($volume,$directories,$file) = File::Spec->splitpath(
												File::Spec->canonpath(
													File::Spec->rel2abs($outDir)));
my $realOut = "$directories$file/$kernelVersion-$kernelName";

# This variable will store the current logfile name
my %logFiles = ();
$logFiles{LOGDIR} = "$realOut/log";
`mkdir -p $logFiles{LOGDIR}`;
$logFiles{FETCH} = "$realOut/log/fetch.log";
$logFiles{KERNEL_BUILD} = "$realOut/log/kernel_build.log";
$logFiles{MODULES_BUILD} = "$realOut/log/modules_build.log";
$logFiles{EDIT} = "$realOut/log/edit.log";
$logFiles{MAKEKPKG_DEBIAN} = "$realOut/log/make-kpkg_debian.log";

# Execute the asked target.
switch($options{t})
{
	case "kernel"
	{kernel();}
	case "modules"
	{modules();}
	case "kernel-modules"
	{kernel_modules();}
	case "tarball"
	{tarball();}
	case "edit"
	{edit();}
	case "fetch"
	{fetch();}
	case "clean"
	{clean();}
	case "clean-binary"
	{clean_binary();}
	else
	{
		print STDERR "Error: invalid target \"$options{t}\"!\n";
		exit 1;
	}
}
# Work done... exit!
exit 0;

# Targets.

# Cleans temporary files.
sub clean
{
	dprint("calling clean()");
	step_print("cleaning temporary files ...");
	`rm -Rf $workDir/$kernelSources`;
	`rm -Rf $workDir/$tarballName`;
}

# Creates a kernel sources tree and exits
sub fetch
{
	clean();
	fetch_and_uncompress();
	print "kernel sources tree created in\n$workDir/$kernelSources\n";
}

# Builds kernel packages.
sub kernel
{
	dprint("calling kernel()");
	backup();
	clean_binary_kernel();
	clean();
	fetch_and_uncompress();
	patch();
	debian();
	kernel_build();
	create_tarball();
	clean();
	print "\nPackages created in $realOut\n";
}

# Builds modules packages.
sub modules
{
	dprint("calling modules()");
	backup();
	clean_binary_modules();
	clean();
	fetch_and_uncompress();
	patch();
	debian();
	modules_build();
	create_tarball();
	clean();
	print "\nPackages created in $realOut\n";
}

# Builds kernel + modules packages.
sub kernel_modules
{
	dprint("calling kernel_modules()");
	backup();
	clean_binary_modules();
	clean();
	fetch_and_uncompress();
	patch();
	debian();
	modules_build();
	kernel_build();
	create_tarball();
	clean();
	print "\nPackages created in $realOut\n";
}

# Does the actual build of the kernel
sub kernel_build
{
	step_print("building kernel packages ...");
	clean_log($logFiles{KERNEL_BUILD});
	command("( cd $workDir/$kernelSources && \\\
echo > debian/official && \\\
nice -n 19 $makekpkg $makekpkgOptions --bzimage buildpackage )",
	$logFiles{KERNEL_BUILD});
	`mkdir -p $realOut`;
	`mv $workDir/kernel-source-[0-9].[0-9].[0-9]*-$kernelName*.changes \\\
$workDir/kernel-doc-[0-9].[0-9].[0-9]*-$kernelName*.deb \\\
$workDir/kernel-headers-[0-9].[0-9].[0-9]*-$kernelName*.deb \\\
$workDir/kernel-image-[0-9].[0-9].[0-9]*-$kernelName*.deb \\\
$workDir/kernel-source-[0-9].[0-9].[0-9]*-$kernelName*.deb \\\
$realOut`;
}

# Does the actual build of modules
sub modules_build
{
	step_print("building modules packages ...");
	clean_log($logFiles{MODULES_BUILD});
	command("( cd $workDir/$kernelSources && \\\
echo > debian/official && \\\
$makekpkg $makekpkgOptions --bzimage modules_image )",
	$logFiles{MODULES_BUILD});
	`mkdir -p $realOut`;
	`mv $workDir/*-module*-[0-9].[0-9].[0-9]*-$kernelName*.deb $realOut`;
}

# Cleans all compiled .deb's.
sub clean_binary
{
	dprint("calling clean_binary()");
	clean();
	clean_binary_kernel();
	clean_binary_modules();
}

# Cleans existing kernel packages in the output directory.
sub clean_binary_kernel
{
	dprint("calling clean_binary_kernel()");
	step_print("cleaning kernel .deb's ...");
# TODO Fails if no file is here. Correct it!
	`rm -Rf $realOut/kernel-source-[0-9].[0-9].[0-9]*$kernelName*.changes \
	$realOut/kernel-doc-[0-9].[0-9].[0-9]*-$kernelName*.deb \
	$realOut/kernel-headers-[0-9].[0-9].[0-9]*-$kernelName*.deb \
	$realOut/kernel-image-[0-9].[0-9].[0-9]*-$kernelName*.deb \
	$realOut/kernel-source-[0-9].[0-9].[0-9]*-$kernelName*.deb`;
	clean_tarball();
}

# Cleans existing modules .deb.
sub clean_binary_modules
{
	dprint("calling clean_binary_modules()");
	step_print("cleaning modules .deb's ...");
	`rm -Rf $realOut/*-module-[0-9].[0-9].[0-9]*-$kernelName*.deb`;
	clean_tarball();
}

# removes the tarball
sub clean_tarball
{
	if (-f "$realOut/$tarballName.tar.bz2")
	{
		`rm -f $realOut/$tarballName.tar.bz2`;
	}
}

# Fetches kernel sources and uncompress them.
sub fetch_and_uncompress
{
	dprint("calling fetch()");
	step_print("fetching kernel sources and creating kernel sources tree ...");
	clean_log($logFiles{FETCH});
	command("( cd $workDir && mkdir -p $kernelSources && \\\
cd $kernelSources && ketchup $kernelVersion )",
	$logFiles{FETCH});
	step_print("copying config file in kernel sources tree ...");
	`cp $buildXmlConfigDir/$kernelConfigFile $workDir/$kernelSources/.config`;
}

# Applies asked patches.
# TODO exit nicely if patching fails
sub patch
{
	dprint("calling patch()");
	step_print("patches");
	my @patches = split(/ /, $buildXmlConfig{PATCHES});
	for (@patches)
	{
		my $patchWithPath = "$buildXmlConfigDir/$_";
		# Check for patch's presence
		if (not -f $patchWithPath)
		{
			print STDERR "patch \"$patchWithPath\" not found!\n";
			exit 1;
		}
		print "applying $_ ...\n";
		my $logFile = "$logFiles{LOGDIR}/$_.log";
		clean_log($logFile);
		command("( cd $workDir/$kernelSources && patch -p1 < $patchWithPath )",
					$logFile);
	}

#	my $patches = $buildXmlConfig{PATCHES};
#	print Dumper($patches);
#	my $i;
#	for $i (0 .. $#patches)
#	{
##		print Dumper($_);
#		my $patchName = $patches[$i]{file};
#		print "applying $patchName ...\n";
#		my $logFile = "$logFiles{LOGDIR}/$patchName.log";
#		clean_log($logFile);
#		command("( cd $workDir/$kernelSources && patch -p1 < $buildXmlConfigDir/$patchName )",
#		$logFile);
#	}
#	exit 1;
}

# Runs make-kpkg debian.
sub debian
{
	dprint("calling debian()");
	step_print("running make-kpkg debian ...");
	clean_log($logFiles{MAKEKPKG_DEBIAN});
	command("( cd $workDir/$kernelSources && $makekpkg debian )",
	$logFiles{MAKEKPKG_DEBIAN});
}

# Creates a backup of old packages if already existing.
sub backup
{
	dprint("calling backup()");
	if (-d $realOut)
	{
		step_print("creating a backup of old files in\n\"$realOut.bak\" ...");
		# Blank the $realOut.bak directory
		if (!(-d "$realOut.bak"))
		{
			`mkdir -p $realOut.bak`;
		}
		else
		{
			`rm -Rf $realOut.bak && mkdir -p $realOut.bak`;
		}
		# Copy .deb's if they exist
		opendir REALOUT, "$realOut.bak";
		my $firstFile = readdir REALOUT; # .
		$firstFile = readdir REALOUT; # ..
		$firstFile = readdir REALOUT; # something?
		if ($firstFile)
		{
			`cp -r $realOut/* $realOut.bak`;
		}
		# Clean existing logs
		`rm -f $realOut/log/*.log`;
	}
}

# Edit the .config using xconfig.
sub edit
{
	dprint("calling edit()");
	clean();
	fetch_and_uncompress();
	patch();
	step_print("edit configuration file:
$kernelConfigFile");
	print "Please save your configuration in the graphical interface when you have
finished editing. If you don't save, the configuration file will be untouched.
Now building and starting the graphical interface ...\n";
	clean_log($logFiles{EDIT});
	command("( cd $workDir/$kernelSources && make xconfig )",
	$logFiles{EDIT});
	step_print("creating backup ...");
	`cp -f $buildXmlConfigDir/$kernelConfigFile \\\
$buildXmlConfigDir/$kernelConfigFile.old`;
	step_print("copynig new configuration in\n$buildXmlConfigDir ...");
	`cp -f $workDir/$kernelSources/.config $buildXmlConfigDir/$kernelConfigFile`;
	print "done\n";
}

# create a tarball and exit
sub tarball
{
	dprint("calling tarball()");
	# clean logs
	if (-d "$realOut/log")
	{
		`rm -Rf $realOut/log`;
	}
	create_tarball();
}

# executes $ARGV[0] and logs the result in $ARGV[1]
# TODO Timeout on child's STDOUT. If nothing is displayed for a long time, show
# log end.
# TODO If an error occurs in the child, show log path!!!!!!
sub command
{
	# Open log file
	open(LOGFILE, "+>> $_[1]") or die "Can't write $_[1]: $!";
	# Disable buffered output (see Perl CookBook, 7.12 "Flushing Output")
	LOGFILE->autoflush(1);
	# Write command in log file
	print LOGFILE "command:\n\"$_[0]\"\n\nResult:\n";
	pipe(README, WRITEME);
	README->autoflush(1);
	WRITEME->autoflush(1);
	if (my $pid = fork)
	{
		# parent
		$SIG{CHLD} = sub { 1 while (( waitpid(-1, WNOHANG)) > 0) };
		close(WRITEME);
	}
	else
	{
	   # child
	   die "cannot fork: $!" unless defined $pid;
	   open(STDOUT, ">&=WRITEME")   or die "Couldn't redirect STDOUT: $!";
	   open(STDERR, ">&=WRITEME")   or die "Couldn't redirect STDOUT: $!";
		STDOUT->autoflush(1);
		STDERR->autoflush(1);
	   close(README);
	   close(LOGFILE);
	   exec($_[0]) or die "
Error while running
$_[0]
Error message: $!

Look at the following log file for more information:
$_[1]";
	}
	while (<README>) { print LOGFILE; }
	close(README);
	close(LOGFILE);
}

# creates a .tar.bz2 file in the output directory with kernel.xml,
# .config, patches and logs
sub create_tarball
{
	step_print("creating $tarballName.tar.bz2 ...");
	# create temp directory
	my $tempdir = "$workDir/$tarballName";
	`mkdir -p $tempdir`;
	# copy kernel.xml
	my $volume;
	my $directories;
	my $file;
	($volume,$directories,$file) = File::Spec->splitpath($options{f});
	`cp -f $buildXmlConfigDir/$file $tempdir/kernel.xml`;
	# copy kernel config file
	`cp -f $buildXmlConfigDir/$buildXmlConfig{KERNEL_CONFIG_FILE} $tempdir/`;
	# copy patches
	my @patches = split(/ /, $buildXmlConfig{PATCHES});
	for (@patches)
	{
		my $patchWithPath = "$buildXmlConfigDir/$_";
		`cp -f $patchWithPath $tempdir/`;
	}
	# copy logs
	if (-d "$realOut/log")
	{
		`mkdir $tempdir/log`;
		`cp -f $realOut/log/*.log $tempdir/log`;
	}
	# compress
	`( cd $workDir && tar cvjf $tarballName.tar.bz2 $tarballName )`;
	# copy tarball in output directory
	`cp -f $workDir/$tarballName.tar.bz2 $realOut`;
}

# blanks the $_[0] log file
sub clean_log
{
	`echo > $_[0]`;
}

# debug print
sub dprint
{
	if ($debugMode)
	{
		print "[debug] $_[0]\n";
	}
}

# Sets $stepCount
sub set_step_count
{
	switch($options{t})
	{
		case "kernel"
		{$stepCount = 10;}
		case "modules"
		{$stepCount = 10;}
		case "kernel-modules"
		{$stepCount = 12;}
		case "edit"
		{$stepCount = 8;}
		case "tarball"
		{$stepCount = 2;}
		case "fetch"
		{$stepCount = 4;}
		case "clean"
		{$stepCount = 2;}
		case "clean-binary"
		{$stepCount = 4;}
		else
		{
			print STDERR "Error: invalid target \"$options{t}\"!\n";
			exit 1;
		}
	}
}

# Prints a step progress
sub step_print
{
	$step = $step + 1;
	print "[$step/$stepCount] $_[0]\n";
}

# Reads the xml file which contains kernel build information.
sub read_build_xml_config
{
	# Those three variables are used to extract the xml file's name
	my $volume;
	my $directories;
	my $file;
	($volume,$directories,$file) = File::Spec->splitpath($options{f});
	step_print("reading \"$file\" ...");
	my $config = eval { XMLin($options{f}, ForceArray => 0, KeyAttr => ['file']) };
	if ($@ || not defined $config->{kernelversion})
	{
		print STDERR "error while reading build configuration XML file!
is it valid XML?\n";
		exit 1;
	}
	if ($debugMode)
		{ dprint("\$config (XML parsing result):\n\n" . Dumper($config)); }
	# Set $buildXmlConfig according to what was read in the XML
	$buildXmlConfig{KERNEL_NAME} = $config->{kernelname};
	$buildXmlConfig{PACKAGE_REVISION} = $config->{packagerevision};
	$buildXmlConfig{KERNEL_VERSION} = $config->{kernelversion};
	$buildXmlConfig{MAKE_KPKG_OPTIONS} = $config->{makekpkgoptions};
	$buildXmlConfig{KERNEL_CONFIG_FILE} = $config->{kernelconfigfile};
	$buildXmlConfig{PATCHES} = $config->{patches};
#	print Dumper($buildXmlConfig{PATCHES});

#	my $patches = $config->{patches}-{patch};
#	print Dumper($patches);
#	print $patches;
#	my %hash = $patches;
#	my @keys = keys %patches;
#	my @patchKeys = keys %buildXmlConfigPatches;
	
#	my %patches = %buildXmlConfigPatches;
#	print Dumper(%patches);
#	for my $patchKey (@patchKeys)
#	{
#		print "$patchKey\n";
#	}
	
	
#	print Dumper($patchesArrayOfHashRef);
#	exit 1;

#	print "size: " . scalar($patchesArrayOfHash) . "\n";
#	for my $patch ($patchesArrayOfHash)
#	{
#		%hash = $patchesArrayOfHash[$i];
#		push($buildXmlConfig{PATCHES} ,[$_]);
#		print "once\n";
#		print Dumper($patch);
#	}
	# Get the build XML config file's directory
	($volume,$directories,$file) = File::Spec->splitpath(
												File::Spec->canonpath(
													File::Spec->rel2abs($options{f})));
	$buildXmlConfigDir = $directories;
	if ($debugMode) { dprint("\%builXmlConfig:\n\n" . Dumper(%buildXmlConfig)); }
}

# Fetches kernel.org gpg key.
#sub gpg
#{
#	print "fetching kernel.org gpg key ...";
#	`gpg --keyserver wwwkeys.pgp.net --recv-keys 0x517D0F0E`;
#}
