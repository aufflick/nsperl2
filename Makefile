

.PHONY: check-env test all nsperl2 Ns clean

define HELPTEXT
echo "" &&\
echo "You need the following environment variables set correctly:" &&\
echo "" &&\
echo "  NSPERL must point to your perl 5.10 installation perl *executable*" &&\
echo "  NSINST must point to your aolserver installation *directory*" &&\
echo "  TCLINST must point to your tcl 8.4 installation *directory*" &&\
echo "  NSSRC must point to your aolserver source tree *directory*" &&\
echo "" &&\
echo "Also be careful of any existing CPATH CINCLUDES or LIBS environment variables" &&\
echo "see INSTALL.txt for other important information" &&\
echo ""
endef

export NSPERL2SRC = $(PWD)

PERLMODULES = Ns Ns-Set Ns-Conn

default:
	@$(HELPTEXT)

# TODO: drive all the perl module related targets automatically from a single list

install: check-env nsperl2 Ns.pm Ns-Set.pm Ns-Conn.pm Ns-TclApi.pm

clean: check-env Ns/Makefile Ns-Set/Makefile Ns-Conn/Makefile Ns-TclApi/Makefile
	cd nsperl2 && $(MAKE) clean
	cd Ns && $(MAKE) clean
	cd Ns-Set && $(MAKE) clean
	cd Ns-Conn && $(MAKE) clean
	cd Ns-TclApi && $(MAKE) clean
	touch nsperl2.h

test: check-env
	cd test && $(NSPERL) test_run.pl

valgrind:
	cd test && $(NSPERL) test_run.pl --valgrind

check-env:
	@test -n "$(NSPERL)" && test -x $(NSPERL) || (echo 'Error: bad NSPERL' && $(HELPTEXT) && false)
	@test -d $(NSINST) && test -x $(NSINST)/bin/nsd || (echo "Error: bad NSINST" && $(HELPTEXT) && false)
	@test -d $(TCLINST) && test -f $(TCLINST)/include/tcl.h || (echo "Error: bad TCLINST" && $(HELPTEXT) && false)
	@test -d $(NSSRC) && test -f $(NSSRC)/nsd/nsd.h || (echo "Error: bad NSSRC" && $(HELPTEXT) && false)
	@test -d $(NSPERL2SRC) && test -f $(NSPERL2SRC)/nsperl2/nsperl2.c || (echo "odd - NSPERL2SRC should get set up correctly by the Makefile: $(NSPERL2SRC)")
	@test -z "$(CPATH)" || echo "CPATH is set - are you sure you want this: $(CPATH)"
	@test -z "$(CINCLUDES)" || echo "CINCLUDES is set - are you sure you want this: $(CINCLUDES)"
	@test -z "$(LIBS)" || echo "LIBS is set - are you sure you want this: $(LIBS)"

nsperl2: check-env $(NSINST)/bin/nsperl2.so

$(NSINST)/bin/nsperl2.so: $(NSPERL2SRC)/nsperl2/*.c $(NSPERL2SRC)/*.h
	cd nsperl2 && $(MAKE) install
	touch $@

%/Makefile: %/Makefile.PL
	cd $* && $(NSPERL) Makefile.PL

# too hard to get make to sensibly model the dependencies here
# (eg. mulitple .pm files, shared typemap, etc).
# make install is pretty quick, so we don't mind that the
# check-env .PHONY rule will force this rule to always run
%.pm: check-env nsperl2 %/Makefile
	cd $* && $(MAKE) install

todo:
	find . ! -name '*~' |xargs grep -r TODO
