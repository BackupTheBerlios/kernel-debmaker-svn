#!/usr/bin/perl

use Getopt::Std;
use Switch;

my $version = "0.2";

# Say hello!
print "kernel-debmaker $version
Copyright 2003-2004 Olivier Ricordeau
This is free software with ABSOLUTELY NO WARRANTY.\n\n";

# Parse command line options with Getopt::Std.
%options=();
getopts("hc:o:w:f:t:",\%options);

# Print help and exit if -h option.
if (defined $options{h})
{
	print "Builds Debian packages of a kernel using a configuration file.
Usage:
kernel-debmaker.pl [-h] [-c KERNEL_DEBMAKER_CONFIG_FILE] [-o OUTPUT_DIR] [-w WORK_DIR] -f BUILD_CONFIG_FILE -t TARGET

-h: Displays this help message.
-c KERNEL_DEBMAKER_CONFIG_FILE: use the specified configuration file.
-o OUTPUT_DIR: use the specified directory to output .deb packages.
-w WORK_DIR: use the specified working directory.
-f BUILD_CONFIG_FILE: use the specified build configuration file.
-t TARGET: build the specified target.
           The available targets are:
           * kernel: builds .deb's of kernel + modules thanks to make-kpkg.
           * modules: builds .deb's of modules using files in /usr/src/modules.
           * kernel-modules: alias for kernel + modules.
           * edit: edit the kernel config file with \"make xconfig\".
           * fetch: fetch sources and create a sources tree.
           * clean: clean temporary files.
           * clean-binary: clean temporary files and built packages.
";
	exit 0;
}

# Check that the arguments are valid.

# Check -c.
my $userPreferences;
if (defined $options{c})
{
	readConfigFile($options{c});
}
else
{
	if (-f "$ENV{HOME}/.kernel-debmaker/config")
	{
		readConfigFile("$ENV{HOME}/.kernel-debmaker/config");
	}
	else
	{
		`mkdir -p $ENV{HOME}/.kernel-debmaker`;
		`touch $ENV{HOME}/.kernel-debmaker/config`;
		print "Error: please fill the configuration file (default: ~/.kernel-debmaker/config)!\n";
		exit 1;
	}
}
# Set variables read from the config file.
my $kernelName = $userPreferences{KERNEL_NAME};
my $packageRevision = $userPreferences{PACKAGE_REVISION};
my $kernelVersion = $userPreferences{KERNEL_VERSION};
my $makekpkgOptions = $userPreferences{MAKE_KPKG_OPTIONS};
my $patches = $userPreferences{PATCHES};
my $kernelConfigFile = $userPreferences{KERNEL_CONFIG_FILE};

# Set other variables
my $makekpkg = "nice -n 9 make-kpkg -rev Custom.$packageRevision --append_to_version -$kernelName";
my $kernelSources = "linux-$kernelVersion";
my $realOut = "$outDir/$kernelVersion-$kernelName";
# Check -o.
if (defined $options{o})
{
	if (!(-d $options{o}))
	{
		`mkdir $options{o}`;
	}
	my $outDir = $options{o};
}
else
{
	my $outDir = "$ENV{HOME}/.kernel-debmaker/output";
}
# Check -w.
if (defined $options{w})
{
	if (!(-d $options{w}))
	{
		`mkdir $options{w}`;
	}
	my $workDir = $options{w};
}
else
{
	my $workDir = "/tmp";
}
# Check -f.
if (not defined $options{f})
{
	print "Error: no build configuration file provided!\n";
	exit 1;
}
if ( (defined $options{f}) && !(-e $options{f}) )
{
	print "Error: build configuration file \"$options{f}\" does not exist!\n";
	exit 1;
}
# Check -t.
if (not defined $options{t})
{
	print "Error: no target specified!\n";
	exit 1;
}

# Execute the asked target.
switch($options{t})
{
	case "kernel" {kernel();}
	case "modules" {modules();}
	case "kernel-modules" {kernel_modules();}
	case "edit" {edit();}
	case "fetch" {fetch();}
	case "clean" {clean();}
	case "clean-binary" {clean_binary();}
	else
	{
		print "Error: invalid target \"$options{t}\"!\n";
		exit 1;
	}
}
# Work done... exit!
exit 0;

# Targets.

# Cleans temporary files.
sub clean
{
	print " + cleaning temporary files ...";
	`rm -Rf $workDir/$kernelSources`;
}

# Builds kernel packages.
sub kernel
{
	backup();
	clean_binary_kernel();
	fetch();
	patch();
	debian();
	print " + building kernel packages ...";
	`( cd $workDir/$kernelSources && \
	echo > debian/official && \
	nice -n 19 $makekpkg $makekpkgOptions \
	--bzimage buildpackage )`;
	`mkdir -p $realOut`;
	`mv $workDir/kernel-source-[0-9].[0-9].[0-9]-$kernelName*.changes \
	$workDir/kernel-doc-[0-9].[0-9].[0-9]-$kernelName*.deb \
	$workDir/kernel-headers-[0-9].[0-9].[0-9]-$kernelName*.deb \
	$workDir/kernel-image-[0-9].[0-9].[0-9]-$kernelName*.deb \
	$workDir/kernel-source-[0-9].[0-9].[0-9]-$kernelName*.deb \
	$realOut`;
	clean();
}

# Builds modules packages.
sub modules
{
	backup();
	clean_binary_modules();
	fetch();
	patch();
	debian();
	print " + building modules packages ...";
	`( cd $workDir/$kernelSources && \
	echo > debian/official && \
	$makekpkg $makekpkgOptions \
	--bzimage modules_image )`;
	`mkdir -p $realOut`;
	`mv $workDir)/*-module*-[0-9].[0-9].[0-9]-$kernelName*.deb $realOut`;
	clean();
}

# Builds kernel + modules packages.
sub kernel_modules
{
	clean_binary_modules();
	fetch();
	patch();
	debian();
	modules();
	kernel();
	clean();
}

# Cleans all compiled .deb's.
sub clean_binary
{
	clean();
	clean_binary_kernel();
	clean_binary_modules();
}


# Cleans existing kernel packages in the output directory.
sub clean_binary_kernel
{
	print " + cleaning kernel .deb's ...";
	`rm -Rf $realOut/kernel-source-[0-9].[0-9].[0-9]*$kernelName*.changes \
	$realOut/kernel-doc-[0-9].[0-9].[0-9]-$kernelName*.deb \
	$realOut/kernel-headers-[0-9].[0-9].[0-9]-$kernelName*.deb \
	$realOut/kernel-image-[0-9].[0-9].[0-9]-$kernelName*.deb \
	$realOut/kernel-source-[0-9].[0-9].[0-9]-$kernelName*.deb`;
}

# Cleans existing modules .deb.
sub clean_binary_modules
{
	print " + cleaning modules .deb's ...";
	`rm -Rf $realOut/*-module-[0-9].[0-9].[0-9]-$kernelName*.deb`;
}

# Fetches kernel sources and uncompress them.
sub fetch
{
	clean();
	print " + fetching kernel sources and creating kernel sources tree ...";
	`( cd $workDir && \
	mkdir -p $kernelSources && \
	cd $kernelSources && \
	nice -n 19 ketchup $kernelVersion )`;
	print " + copying config file in $workDir/$kernelSources";
	`cp $kernelConfigFile \
	$workDir/$kernelSources/.config`;
}

# Applies asked patches.
sub patch
{
	for ($patches)
	{
		print " + applying $_ ...";
		`( cd $workDir/$kernelSources) && patch -p1 < $_ )`;
	}
}

# Runs make-kpkg debian.
sub debian
{
	print " + running make-kpkg debian ...";
	`( cd $workDir/$kernelSources && $makekpkg debian )`;
}

# Creates a backup of old packages if already existing.
sub backup
{
	if (-d $realOut)
	{
		print " + creating a backup of old files in $realOut.bak ...";
		`mkdir $realOut.bak && cp -r $realOut/* $realOut.bak`;
	}
}

# Edit the .config using xconfig.
sub edit
{
	fetch();
	patch();
	print " + editing $kernelConfigFile";
	print " + kernel config file with current sources.";
	print " + please save your configuration when you have finished editing!";
	`( cd $workDir/$kernelSources && make xconfig )`,
	print " + creating backup ...";
	`cp -f $kernelConfigFile $kernelConfigFile.old`;
	print " + copynig new configuration in";
	print " + $kernelConfigFile ...";
	`cp -f $workDir/$kernelSources/.config $kernelConfigFile`;
}

# Fetches kernel.org gpg key.
sub gpg
{
	print " + fetching kernel.org gpg key ...";
	`gpg --keyserver wwwkeys.pgp.net --recv-keys 0x517D0F0E`;
}

sub readConfigFile
{
	while ($_[0])
	{
		chomp;                  # no newline
		s/#.*//;                # no comments
		s/^\s+//;               # no leading white
		s/\s+$//;               # no trailing white
		next unless length;     # anything left?
		my ($var, $value) = split(/\s*=\s*/, $_, 2);
		$userPreferences{$var} = $value;
	}
}
