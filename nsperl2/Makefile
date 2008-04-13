NSHOME = $(NSINST)
# need nsd.h to get at NsInterp
NSD_CFLAGS = -I$(NSSRC)/nsd

# being careful to put the perl libs at the end so as not to change which tcl gets linked

PERL_LIBS = $(filter-out $(LIBS),$(strip $(shell $(NSPERL) -MExtUtils::Embed -e ldopts)))
PERL_CFLAGS := $(filter-out $(CFLAGS),$(shell $(NSPERL) -MExtUtils::Embed -e ccopts))

MOD      =  nsperl2
OBJS     = nsperl2.o nsperl2_helpers.o
MODINIT = NsPerl2_ModInit

include  $(NSHOME)/include/ns.mak

LIBS := $(LIBS) $(PERL_LIBS)
CFLAGS := $(CFLAGS) $(NSD_CFLAGS) $(PERL_CFLAGS)
