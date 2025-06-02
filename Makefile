# A simple shell script makefile.
.POSIX:

EXEC=clup
EXT=sh
SRC_FILE=$(EXEC).$(EXT)

# Default installation directory.
DIR=/usr/local/bin
INSTALL_PATH=$(DIR)/$(EXEC)

# Uninstall record.
UNINST=Uninstall

.PHONY: install uninstall
install:
	@cp $(SRC_FILE) $(INSTALL_PATH)
	@printf "%s\n" $(INSTALL_PATH) > $(UNINST)
	@chmod 0444 $(UNINST)        # Make uninstall record read-only
	@chmod 0111 $(INSTALL_PATH)  # Set executable permissions
	@echo $(EXEC) installed in $(DIR).

uninstall:
	@xargs rm -f < $(UNINST)
	@rm -f $(UNINST)
	@echo $(EXEC) has been removed.

