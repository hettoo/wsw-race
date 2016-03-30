WSW_DIR = ~/.local/share/warsow-2.1
EXECUTE_DIR = .
EXECUTABLE = wsw-server
MOD = basewsw

NAME = hrace
THIS = Makefile
SOURCE_DIR = source
GAMETYPES_DIR = /progs/gametypes/
BASE_MOD = basewsw
CONFIG_DIR = configs/server/gametypes
FILES = $(shell find $(SOURCE_DIR))
CFG = $(NAME).cfg

PK3 = $(NAME)-010.pk3
EVERY_PK3 = $(NAME)-*.pk3

all: dist

dist: $(PK3)

$(PK3): $(FILES) $(THIS)
	rm -f $(PK3)
	cd $(SOURCE_DIR) && zip ../$(PK3) -r -xi *

local: dist
	cp $(PK3) $(WSW_DIR)/$(BASE_MOD)/

run: local
	cd $(EXECUTE_DIR) && $(EXECUTABLE) +set fs_game $(MOD) +set g_gametype $(NAME)

clean:
	rm -f $(EVERY_PK3)

destroy:
	rm -f $(WSW_DIR)/$(BASE_MOD)/$(EVERY_PK3)
	rm -f $(WSW_DIR)/$(BASE_MOD)/$(CONFIG_DIR)/$(CFG)
	rm -f $(WSW_DIR)/$(MOD)/$(CONFIG_DIR)/$(CFG)

.PHONY: all dist local run clean destroy
