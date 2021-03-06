SRC_DIR := src
PROC_DIR := preprocessed
BIN_DIR := bin
OUT_DIR := output
STAMP_DIR := stamps
MARKDOWN_DIR := markdown

CXXFLAGS := -Wall -Wextra -Wpedantic -Werror -ggdb -std=c++11 -Isrc
LIBS := -Wl,-lboost_regex
GPP := gpp
GPPMACROS := macros.gpp
GPPFLAGS := -U "" "" "(" "," ")" "(" ")" "@" "" -M "@" "\n" " " " " "\n" "(" ")"  -I. --include $(GPPMACROS)

SRC := $(wildcard $(SRC_DIR)/*.cpp)
SRC_PROC := $(shell grep 'CALL[0-9]' $(SRC) -l )
SRC_NOPROC := $(shell grep 'CALL[0-9]' $(SRC) -L )
PROC_FUNC := $(patsubst $(SRC_DIR)/%.cpp,$(PROC_DIR)/%-function.cpp,$(SRC_PROC))
PROC_PIPE := $(patsubst $(SRC_DIR)/%.cpp,$(PROC_DIR)/%-pipe.cpp,$(SRC_PROC))
PROC_ALL := $(PROC_FUNC) $(PROC_PIPE)
BINARIES_PROC := $(patsubst $(PROC_DIR)/%.cpp,$(BIN_DIR)/%,$(PROC_ALL))
BINARIES_NOPROC := $(patsubst $(SRC_DIR)/%.cpp,$(BIN_DIR)/%,$(SRC_NOPROC))
BINARIES := $(BINARIES_PROC) $(BINARIES_NOPROC)
OUTPUTS := $(patsubst $(BIN_DIR)/%,$(OUT_DIR)/%.out,$(BINARIES))
COMPARE_STAMPS := $(patsubst $(SRC_DIR)/%.cpp,$(STAMP_DIR)/%-compare.stamp,$(SRC_PROC))


all: markdown

list-sources: $(SRC_NOPROC) $(PROC_ALL)
	@echo  $^

process: $(PROC_ALL)

binaries: $(BINARIES)

outputs: $(OUTPUTS)

build: outputs $(COMPARE_STAMPS)

markdown: build
	@- mkdir -p $(MARKDOWN_DIR)
	$(Q) python3 ./docgen.py --ext md --targetdir $(MARKDOWN_DIR)

deploy: markdown
	$(if $(TARGETDIR),,$(error TARGETDIR is not defined))
	$(Q) cp $(MARKDOWN_DIR)/* $(TARGETDIR)

clean:
	-$(Q) $(RM) $(PROC_DIR)/* $(BIN_DIR)/* $(OUT_DIR)/* $(STAMP_DIR)/*

help:
	@echo 'Makefile for a pelican Web site                                        '
	@echo '                                                                       '
	@echo 'Common usage:                                                          '
	@echo '   make build                       build examples and generate output '
	@echo '   make deploy TARGETDIR=~/work/homepage/new/content/pages/boost-range '
	@echo '                                    deploy markdown doc to TARGETDIR   '
	@echo '                                                                       '
	@echo 'Other commands:                                                        '
	@echo '   make markdown                    build markdown documentation       '
	@echo '   make clean                       clean autogenerated build files    '
	@echo '   make -s list-sources             print a list of source files       '
	@echo '                                                                       '
	@echo 'Options:                                                               '
	@echo '   make Q=@                         don't show commandlines            '
	@echo '   make SHOW_OUTPUT=1               show example binary stdout         '


$(PROC_DIR)/%-function.cpp: $(SRC_DIR)/%.cpp $(GPPMACROS)
	@- mkdir -p $(PROC_DIR)
	$(Q) $(GPP) $(GPPFLAGS) $(GPPEXTRA) $< -o $@

$(PROC_DIR)/%-pipe.cpp: $(SRC_DIR)/%.cpp
	@- mkdir -p $(PROC_DIR)
	$(Q) $(GPP) $(GPPFLAGS) $(GPPEXTRA) $< -o $@ -D PIPE

$(BIN_DIR)/%: $(PROC_DIR)/%.cpp
	@- mkdir -p $(BIN_DIR)
	$(Q) $(CXX) $(CXXFLAGS) $(LIBS) -o $@ $<

$(BIN_DIR)/%: $(SRC_DIR)/%.cpp
	@- mkdir -p $(BIN_DIR)
	$(Q) $(CXX) $(CXXFLAGS) $(LIBS) -o $@ $<

$(OUT_DIR)/%.out: $(BIN_DIR)/%
	@- mkdir -p $(OUT_DIR)
	$(if $(SHOW_OUTPUT),$(Q) echo $<)
	$(Q) ./$< > $@
	$(if $(SHOW_OUTPUT),$(Q) cat $@)

$(STAMP_DIR)/%-compare.stamp: $(OUT_DIR)/%-function.out $(OUT_DIR)/%-pipe.out
	@- mkdir -p $(STAMP_DIR)
	$(Q) test `md5sum $^ | cut -d ' ' -f 1 | uniq | wc -l` -eq 1
	$(Q) touch $@


.PRECIOUS: $(BIN_DIR)/% $(OUT_DIR)/% $(PROC_DIR)/% $(STAMP_DIR)/%

.PHONY: all list-sources process binaries outputs clean help markdown html deploy
