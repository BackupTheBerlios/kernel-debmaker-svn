# First, include your kdm file. Look in ./examples/ for examples.
# ex:    include /home/foo/my_kdm_file.kdm
include ../examples/2.6.4-srv-presario9xx/2.6.4-srv-presario9xx.kdm


# (* Begin of the config section *)

# working directory
# the place where the "ketchup" script will create a new linux-... directory
# concaining a kernel sources tree.
# ex: WORK_DIR = /tmp
WORK_DIR = /tmp

# the directory where the .deb's will be output.
# ex: OUT_DIR=/tmp/kernel_packages
# warning! this Makefile will overwrite files in this directory!
# You might want to output the packages in /tmp/something and then move them.
OUT_DIR = /root/kernel_packages

# (* End of the config section *)




















###########################################################################
#      After this limit, do not edit this file unless you are sure of     #
#                           what you are doing.                           #
###########################################################################


MAKE_KPKG = nice -n 9 make-kpkg -rev Custom.$(PACKAGE_REVISION) --append_to_version -$(KERNEL_NAME)

KERNEL_SOURCES=linux-$(KERNEL_VERSION)

REAL_OUT = $(OUT_DIR)/$(KERNEL_VERSION)-$(KERNEL_NAME)

KETCHUP = /usr/bin/ketchup

kernel: backup clean-binary-kernel fetch patch debian _kernel clean

_kernel:
	@echo " + building kernel packages ..."
	@( cd $(WORK_DIR)/$(KERNEL_SOURCES) && \
	echo > debian/official && \
	nice -n 19 $(MAKE_KPKG) $(MAKE_KPKG_OPTIONS) \
	--bzimage buildpackage )
	@mkdir -p $(REAL_OUT)
	@mv $(WORK_DIR)/kernel-source-[0-9].[0-9].[0-9]-$(KERNEL_NAME)*.changes \
	$(WORK_DIR)/kernel-doc-[0-9].[0-9].[0-9]-$(KERNEL_NAME)*.deb \
	$(WORK_DIR)/kernel-headers-[0-9].[0-9].[0-9]-$(KERNEL_NAME)*.deb \
	$(WORK_DIR)/kernel-image-[0-9].[0-9].[0-9]-$(KERNEL_NAME)*.deb \
	$(WORK_DIR)/kernel-source-[0-9].[0-9].[0-9]-$(KERNEL_NAME)*.deb \
	$(REAL_OUT)

modules: backup clean-binary-modules fetch patch debian _modules clean

_modules: 
	@echo " + building modules packages ..."
	@( cd $(WORK_DIR)/$(KERNEL_SOURCES) && \
	echo > debian/official && \
	nice -n 19 $(MAKE_KPKG) $(MAKE_KPKG_OPTIONS) \
	--bzimage modules_image )
	@mkdir -p $(REAL_OUT)
	@mv $(WORK_DIR)/*-module*-[0-9].[0-9].[0-9]-$(KERNEL_NAME)*.deb \
	$(REAL_OUT)

kernel-modules: clean-binary-modules fetch patch debian _modules _kernel clean

edit: fetch patch
	@echo " + editing $(KERNEL_CONFIG_FILE)"
	@echo " + kernel config file with current sources."
	@echo " + please save your configuration when you have finished editing!"
	@( cd $(WORK_DIR)/$(KERNEL_SOURCES) && \
	make xconfig )
	@echo " + creating backup ..."
	@cp -f $(KERNEL_CONFIG_FILE) $(KERNEL_CONFIG_FILE).old
	@echo " + copynig new configuration in"
	@echo " + $(KERNEL_CONFIG_FILE) ..."
	@cp -f $(WORK_DIR)/$(KERNEL_SOURCES)/.config \
	$(KERNEL_CONFIG_FILE)

clean-binary-modules:
	@echo " + cleaning modules .deb's ..."
	@rm -Rf $(REAL_OUT)/*-module-[0-9].[0-9].[0-9]-$(KERNEL_NAME)*.deb


clean-binary-kernel:
	@echo " + cleaning kernel .deb's ..."
	@rm -Rf $(REAL_OUT)/kernel-source-[0-9].[0-9].[0-9]*$(KERNEL_NAME)*.changes \
	$(REAL_OUT)/kernel-doc-[0-9].[0-9].[0-9]-$(KERNEL_NAME)*.deb \
	$(REAL_OUT)/kernel-headers-[0-9].[0-9].[0-9]-$(KERNEL_NAME)*.deb \
	$(REAL_OUT)/kernel-image-[0-9].[0-9].[0-9]-$(KERNEL_NAME)*.deb \
	$(REAL_OUT)/kernel-source-[0-9].[0-9].[0-9]-$(KERNEL_NAME)*.deb

clean-binary: clean clean-binary-kernel clean-binary-modules

clean:
	@echo " + cleaning temporary files ..."
	@rm -Rf $(WORK_DIR)/$(KERNEL_SOURCES)

# applies asked patches
patch:
	@for i in $(PATCHES);\
	do\
	( echo " + applying $$i ..." && \
	cd $(WORK_DIR)/$(KERNEL_SOURCES) && \
	patch -p1 < $$i ) || exit 1;\
	done

debian:
	@echo " + running make-kpkg debian ..."
	@( cd $(WORK_DIR)/$(KERNEL_SOURCES) && \
	$(MAKE_KPKG) debian )

backup:
	@if [ -d $(REAL_OUT) ]; then \
	echo " + creating a backup of old files in" && \
	echo "   $(REAL_OUT).bak ..." && \
	mkdir $(REAL_OUT).bak && cp -r $(REAL_OUT)/* $(REAL_OUT).bak \
	fi;

#gpg:
#	@echo " + fetching kernel.org gpg key ..."
#	@gpg --keyserver wwwkeys.pgp.net --recv-keys 0x517D0F0E

fetch: clean# gpg
	@echo " + fetching kernel sources and creating kernel sources tree ..."
	@( cd $(WORK_DIR) && \
	mkdir -p $(KERNEL_SOURCES) && \
	cd $(KERNEL_SOURCES) && \
	nice -n 19 $(KETCHUP) $(KERNEL_VERSION) )
	@echo " + copying config file in $(WORK_DIR)/$(KERNEL_SOURCES)"
	@cp $(KERNEL_CONFIG_FILE) \
	$(WORK_DIR)/$(KERNEL_SOURCES)/.config

#.PHONY: gpg
