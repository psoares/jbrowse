# "Standard rules" for building jbrowse tracks.
# Intended as an example of how to use the scripts, and also, how to automate their use.

# Primary targets:
# jbrowse  -- build tracks from { *.fa, *.fasta, *.gff, *.gff3, *.bed, *.wig, config.js }
#  reference-sequences  -- build reference sequences from { *.fa, *.fasta }
#  track-info  -- build track info from { *.gff, *.gff3, *.bed, *.wig, config.js } + reference sequences
#  name-index  -- build name index from track info
# jbrowse-clean  -- remove jbrowse track directories
# bed2gff  -- convert all BED files into GFF files, using a simple rule


# Variables

# Default path to cloned jbrowse repository
# Edit the following line to reflect your jbrowse root path:
# (Can also override with 'make JROOT=...' on command line)
ifndef JROOT
JROOT = $(dir $(MAKEFILE_LIST))..
# JROOT = /usr/local/jbrowse
endif

# Path to Perl scripts
JBIN  = $(JROOT)/bin

# JBrowse Perl scripts
PREPARE_REFSEQS = perl $(JBIN)/prepare-refseqs.pl
BIODB_TO_JSON   = perl $(JBIN)/biodb-to-json.pl
GFF_TO_JSON     = perl $(JBIN)/gff-to-json.pl
WIG_TO_JSON     = perl $(JBIN)/wig-to-json.pl
GENERATE_NAMES  = perl $(JBIN)/generate-names.pl

# Current working directory (cwd):
# reference sequences (concatenation of all FASTA files in cwd)
REFSEQS = _refseqs.fasta

# all other FASTA files in cwd
ALL_FASTA  = $(filter-out $(REFSEQS),$(wildcard *.fasta) $(wildcard *.fa))

# all BED files in cwd
ALL_BED    = $(wildcard *.bed)

# GFF files autogenerated from BED files
ALL_BED2GFF = $(subst .bed,.gff,$(ALL_BED))

# all GFF3 files in cwd
ALL_GFF3    = $(wildcard *.gff3)

# GFF files autolinked from GFF3 files
ALL_GFF3GFF = $(subst .gff3,.gff,$(ALL_GFF3))

# all GFF files in cwd, excluding those auto-generated from BED or GFF3 files
ALL_GFF    = $(filter-out $(ALL_BED2GFF) $(ALL_GFF3GFF),$(wildcard *.gff))

# all WIG files in cwd
ALL_WIG    = $(wildcard *.wig)

# name of JBrowse config file in cwd
CONFIG = config.js

# JBrowse target files
CHUNKS = data/refSeqs.js
PATRICIA  = names/root.json

# wildcard expression for generated files of feature names
NAMES = data/tracks/*/*/names.json

# proxy targets directory: touching "$(PROCESSED)/X" indicates successful processing of file "X"
PROCESSED = processed

# staging directory
STAGE = stage

# name of staged GFF file
STAGED_GFF = staged.gff

# proxy targets for complete processing of BED, GFF and WIG files into JBrowse tracks
TRACKS = $(addprefix $(PROCESSED)/,$(ALL_BED2GFF) $(ALL_GFF3GFF) $(ALL_GFF) $(ALL_WIG))

# target directories
DIRS = $(PROCESSED) $(STAGE) $(dir $(CHUNKS) $(PATRICIA))



# Public phony targets
PHONIES = jbrowse jbrowse-clean reference-sequences track-info name-index bed2gff
.PHONY: $(PHONIES)

jbrowse: reference-sequences track-info name-index

reference-sequences: $(CHUNKS)

track-info: $(TRACKS)

name-index: $(PATRICIA)

jbrowse-clean:
	rm -rf $(DIRS)

bed2gff: $(ALL_BED2GFF)

# Private rules

# names
$(PATRICIA): $(DIRS) $(TRACKS)
	$(GENERATE_NAMES) $(NAMES)

# directories
# one-off dirs
$(DIRS):
	mkdir $@

# aggregated reference sequences
$(REFSEQS): $(ALL_FASTA)
	 cat $(ALL_FASTA) >$@

# sequence chunking for client
$(CHUNKS): $(DIRS) $(REFSEQS)
	$(PREPARE_REFSEQS) --fasta $(REFSEQS)

# staging directories for GFF, FASTA & JBrowse config files
$(STAGE)/%: $(DIRS) %.gff
	test -d $@ || mkdir $@

# staged GFF
# adds fake "##sequence-region" lines to the GFF, to work around certain weird upstream bugs with Bio::DB::SeqFeature::Store
$(STAGE)/%/$(STAGED_GFF): $(STAGE)/% %.gff
	cat $*.gff | perl -e '@in=<>;for(@in){@f=split/\t/;if(@f==9){$$len{$$f[0]}=$$f[4] if $$f[4]>$$len{$$f[0]}}}print"##gff-version 3\n",map("##sequence-region $$_ 1 $$len{$$_}\n",keys%len),@in' >$@

# staged FASTA
$(STAGE)/%/$(REFSEQS): $(STAGE)/% $(REFSEQS)
	ln -sf $(CURDIR)/$(REFSEQS) $(STAGE)/$*/$(REFSEQS)

# staged JBrowse config file
$(STAGE)/%/$(CONFIG): $(DIRS) $(CHUNKS) $(STAGE)/% $(STAGE)/%/$(STAGED_GFF) $(CONFIG)
	echo '{' >$@
	echo '  "description": "$* tracks",' >>$@
	echo '  "db_adaptor": "Bio::DB::SeqFeature::Store",' >>$@
	echo '  "db_args": { "-adaptor": "memory",' >>$@
	echo '               "-dir": "$(STAGE)/$*" },' >>$@
	echo '  "TRACK DEFAULTS": {' >>$@
	echo '    "class": "feature",' >>$@
	echo '    "autocomplete": "all"' >>$@
	echo '  },' >>$@
	echo '  "tracks": [' >>$@
	cat $(CONFIG) | perl -pe 's/"track"\s*:\s*"([^"]*)"/"track": "$*_$$1"/g;s/"key"\s*:\s*"([^"]*)"/"key": "$* $$1"/g' >>$@
	echo '  ]' >>$@
	echo '}' >>$@

# two ways of making GFF files into JSON: with & without config file
# JBrowse config file + GFF -> Bio::DB -> JSON
$(PROCESSED)/%.gff: $(CHUNKS) $(STAGE)/%/$(STAGED_GFF) $(STAGE)/%/$(CONFIG) %.gff $(CONFIG)
	$(BIODB_TO_JSON) --conf $(STAGE)/$*/$(CONFIG) | tee $*.log
	touch $@

# fallback (no config file): GFF -> JSON
# (it should not be necessary to include $(STAGED_GFF) in the deps list for this rule, but make seems to get confused otherwise)
$(PROCESSED)/%.gff: $(CHUNKS) $(STAGE)/%/$(STAGED_GFF) %.gff
	$(GFF_TO_JSON) --gff $*.gff --key $* --autocomplete all --featlabel | tee $*.log
	touch $@

# WIG -> JSON
$(PROCESSED)/%.wig: $(CHUNKS) %.wig
	$(WIG_TO_JSON) --wig $*.wig --tracklabel $*

# BED -> GFF
%.gff: %.bed
	cat $< | perl -ane 'print join ("\t", $$F[0], "bed2gff", "feature", $$F[1]+1, $$F[2]+1, ".", ".", ".", ""), "\n" if @F >= 3' >$@

# GFF3 -> GFF
%.gff: %.gff3
	ln -sf $< $@

# don't delete intermediate files
.SECONDARY: