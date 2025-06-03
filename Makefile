# A simple shell script makefile.
.POSIX:

EXEC=clup
EXT=sh
SRC_FILE=$(EXEC).$(EXT)

# Default installation directory.
INSTALL_DIR=/usr/local/bin
INSTALL_PATH=$(INSTALL_DIR)/$(EXEC)

# Uninstall record.
UNINST=Uninstall

.PHONY: install uninstall
install:
	@cp $(SRC_FILE) $(INSTALL_PATH)
	@printf "%s\n" $(INSTALL_PATH) > $(UNINST)
	@chmod 0444 $(UNINST)        # Make uninstall record read-only
	@chmod +x $(INSTALL_PATH)  # Set executable permissions
	@echo $(EXEC) installed in $(INSTALL_DIR).

uninstall:
	@xargs rm -f < $(UNINST)
	@rm -f $(UNINST)
	@echo $(EXEC) has been removed.

