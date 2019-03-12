OUTPUTS :=
DEPTS :=


package: installer.run
OUTPUTS += installer.run
installer.run: $(DEPTS)
	makeself \
		--tar-extra "--exclude=.gitkeep" \
		"./package/" "$(notdir $@)" "Deploy CTFd based on Docker on a CentOS 7+ machine" ./bootstrap.sh

clean:
	rm -f $(OUTPUTS)

purge:
	rm -rf $(OUTPUTS) $(DEPTS)