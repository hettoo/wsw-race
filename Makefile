WSW_DIR = ~/.warsow-1.0
EXECUTE_DIR = .
EXECUTABLE = wsw-server
MOD = basewsw

NAME = race
SERVER_CMD = cd $(EXECUTE_DIR) && $(EXECUTABLE) +set fs_game $(MOD) \
			 +set g_gametype $(NAME)
THIS = Makefile
SOURCE_DIR = source
GAMETYPES_DIR = /progs/gametypes/
SOURCE_DESTINATION_DIR = $(GAMETYPES_DIR)$(NAME)/
TMP_DIR = tmp
BASE_MOD = basewsw
CONFIG_DIR = configs/server/gametypes
FILES = $(shell find $(SOURCE_DIR))
SETTINGS_FILE = $(SOURCE_DIR)/race.as
EVERY_PK3 = $(NAME)-*.pk3
CFG = $(NAME).cfg

VERSION = $(shell grep 'gametype\.version =' $(SETTINGS_FILE) \
		  | head -n1 | sed 's/.*"\(.*\)".*/\1/')
VERSION_WORD = $(subst .,_,$(VERSION))
PK3 = $(NAME)-$(VERSION_WORD).pk3

all: dist

dist: $(PK3)

$(PK3): $(FILES) $(THIS)
	rm -rf $(TMP_DIR)
	mkdir -p $(TMP_DIR)$(SOURCE_DESTINATION_DIR)
	rm -f $(PK3)
	cp -r $(SOURCE_DIR)/* $(TMP_DIR)$(SOURCE_DESTINATION_DIR)
	cd $(TMP_DIR) && zip ../$(PK3) -r -xi *
	rm -r $(TMP_DIR)

local: dist
	cp $(PK3) $(WSW_DIR)/$(BASE_MOD)/

production: local
	$(SERVER_CMD)

productionloop: local
	while true; do $(SERVER_CMD); done

clean:
	rm -f $(EVERY_PK3)

destroy:
	rm -f $(WSW_DIR)/$(BASE_MOD)/$(EVERY_PK3)
	rm -f $(WSW_DIR)/$(BASE_MOD)/$(CONFIG_DIR)/$(CFG)
	rm -f $(WSW_DIR)/$(MOD)/$(CONFIG_DIR)/$(CFG)

restart: destroy local

dev: restart
	$(SERVER_CMD)

.PHONY: all dist local production productionloop clean destroy restart dev
