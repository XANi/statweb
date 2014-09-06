.PHONY: agent dashboard listener clean

all: agent dashboard listener
	echo ok

agent:
	$(MAKE) -w -C agent

dashboard:
	$(MAKE) -w -C dashboard

listener:
	$(MAKE) -w -C listener

clean:
	$(MAKE) -w -C agent clean
	$(MAKE) -w -C dashboard clean
	$(MAKE) -w -C listener clean

distclean:
	$(MAKE) -w -C agent distclean
	$(MAKE) -w -C dashboard distclean
	$(MAKE) -w -C listener distclean
