#include "../nsperl2.h"
#include "ppport.h"

/* nasty - these api's in tclset should really be public... */
#include "nsd_tclset_extract.c"


MODULE = Ns::Set		PACKAGE = Ns::Set		PREFIX = Ns_Set

nsperl2_Ns_Set *new(char *class, HV *args)
  CODE:
    char *name, *persist = NULL;
    SV **name_svh, **persist_svh;
    STRLEN name_len, n_a;
    int persist_perl, persist_tcl;

    name_svh = hv_fetch(args, "name", 4, FALSE);
    if(name_svh)
        name = SvPV(*name_svh, name_len);
    if(!name_svh || !name_len)
        croak("Ns::Set new requires name argument");

    persist_svh = hv_fetch(args, "persist", 6, FALSE);
    if(persist_svh)
        persist = SvPV(*persist_svh, n_a);

    if(persist) {
        if(STREQ(persist, "perl")) {
             persist_tcl = 0;
             persist_perl = 1;
    
        } else if(STREQ(persist, "tcl")) {
             persist_tcl = 1;
             persist_perl = 1;
    
        } else
             persist_tcl = persist_perl = 0;
    }

    RETVAL = nsperl2_Ns_Set_new(name, NULL, NULL, persist_perl, persist_tcl);
  OUTPUT:
    RETVAL

const char *setId(nsperl2_Ns_Set *self)
     CODE:
        if(!self->setId)
            XSRETURN_UNDEF;

        RETVAL = self->setId;
     OUTPUT:
        RETVAL

# class sub - no self
nsperl2_Ns_Set * get_by_setId(char * setId)
    CODE:
        NsInterp *itPtr = __nsperl2_get_itPtr();
        Ns_Set *set;
        if(itPtr == NULL)
            croak("Can't get Ns_Set by setID - no nsd itPtr");

        if (LookupSet(itPtr, setId, 0, &set) != TCL_OK) /* using code copied from tclset.c and #included above */
           XSRETURN_UNDEF;
        if (!set)
           XSRETURN_UNDEF;
        RETVAL = nsperl2_Ns_Set_new(NULL, set, setId, 1, 0); /* set persist_perl on so we don't free it in DESTROY, don't care about tcl persistence either way */
    OUTPUT:
        RETVAL


const char *_register(nsperl2_Ns_Set * self, char *persistent)
    CODE:
        NsInterp *itPtr = __nsperl2_get_itPtr();
        int persist_perl, persist_tcl;
        int flags = 0;
        Tcl_Interp *interp = __nsperl2_get_tcl_interp();
        if(itPtr == NULL || interp == NULL)
            croak("Ns::Set register unable to get itPtr or interp");

        if(STREQ(persistent, "perl")) {
             self->persist_perl = 1;
             self->persist_tcl = 0;
        } else if (STREQ(persistent, "tcl")) {
             self->persist_perl = 1;
             self->persist_tcl = 1;
        } else {
             self->persist_perl = 0;
             self->persist_tcl = 0;
        }

        /* not 100% sure I have this right... */
        if(!self->persist_tcl)
            flags = NS_TCL_SET_SHARED;
        else
            flags = NS_TCL_SET_DYNAMIC;
        if (EnterSet(itPtr, self->set, flags) != TCL_OK)
           XSRETURN_UNDEF;

        /* the setId is left on the tcl stack for us */
        
        RETVAL = Tcl_GetStringResult(interp); /* do i need to strcpy this? */
        Tcl_ResetResult(interp);
    OUTPUT:
        RETVAL

void DESTROY(nsperl2_Ns_Set *self)
  CODE:
    if(!self->persist_perl)
        Ns_SetFree( self->set );

    safefree(self);

# need code to find setId in tcl hash - is that even possible? does register do that for us?

int isnull(nsperl2_Ns_Set *self, int field)
    CODE:
        RETVAL = Ns_SetValue(self->set, field) ? 0 : 1;
    OUTPUT:
        RETVAL

int
Ns_SetSize(self)
    nsperl2_Ns_Set * self
    ALIAS:
        size = 1
    CODE:
        RETVAL = self->set->size;
    OUTPUT:
        RETVAL

char *
Ns_SetName(self)
    nsperl2_Ns_Set * self
    CODE:
        RETVAL = self->set->name;
    ALIAS:
        name = 1
    OUTPUT:
        RETVAL

char *
Ns_SetKey(self, idx)
    nsperl2_Ns_Set * self
    int idx
    CODE:
        RETVAL = self->set->fields[idx].name;
    OUTPUT:
        RETVAL
    ALIAS:
        key = 1

char *
Ns_SetValue(self, idx)
    nsperl2_Ns_Set * self
    int idx
    ALIAS:
        value = 1
    CODE:
        RETVAL = self->set->fields[idx].value;
    OUTPUT:
        RETVAL

int
Ns_SetLast(self)
    nsperl2_Ns_Set * self
    ALIAS:
        last = 1
    CODE:
        if(!self->set)
            croak("no set element in struct");
        if(self->set->size == 0)
             XSRETURN_UNDEF;
        RETVAL = (self->set->size)-1;
    OUTPUT:
        RETVAL


nsperl2_Ns_Set *
copy(self)
	nsperl2_Ns_Set *	self
    CODE:
        RETVAL = nsperl2_Ns_Set_new(NULL, Ns_SetCopy(self->set), NULL, 0, 0);

void
Ns_SetDelete(self, index)
	nsperl2_Ns_Set * self
	int	index
    ALIAS:
        delete = 1
    C_ARGS:
        self->set, index

void
Ns_SetDeleteKey(self, key)
	nsperl2_Ns_Set * self
	char *	key
    ALIAS:
        delkey = 1
    C_ARGS:
        self->set, key

int
Ns_SetFind(self, key)
	nsperl2_Ns_Set * self
	char *	key
    ALIAS:
        find = 1
    C_ARGS:
        self->set, key

#int
#findCmp(self, key, arg2)
#	nsperl2_Ns_Set * self
#	char *	key
#	int ( * cmp ) ( char * s1, char * s2 )	arg2

char *
Ns_SetGet(self, key)
	nsperl2_Ns_Set * self
	char *	key
    ALIAS:
        get = 1
    C_ARGS:
        self->set, key


#char *
#getCmp(self, key, arg2)
#	nsperl2_Ns_Set * self
#	char *	key
#	int ( * cmp ) ( char * s1, char * s2 )	arg2

void
Ns_SetIDeleteKey(self, key)
	nsperl2_Ns_Set * self
	char *	key
    ALIAS:
        idelkey = 1
    C_ARGS:
        self->set, key

int
Ns_SetIFind(self, key)
	nsperl2_Ns_Set * self
	char *	key
    ALIAS:
        ifind = 1
    C_ARGS:
        self->set, key

char *
Ns_SetIGet(self, key)
	nsperl2_Ns_Set * self
	char *	key
    ALIAS:
        iget = 1
    C_ARGS:
        self->set, key

int
Ns_SetIUnique(self, key)
	nsperl2_Ns_Set * self
	char *	key
    ALIAS:
        iunique = 1
    C_ARGS:
        self->set, key

#Ns_Set *
#listFind(selfs, name)
#	nsperl2_Ns_Set ** selfs
#	char *	name

#void
#listFree(selfs)
#	nsperl2_Ns_Set ** selfs

void
Ns_SetMerge(high, low)
	nsperl2_Ns_Set *	high
	nsperl2_Ns_Set *	low
    ALIAS:
        merge = 1
    C_ARGS:
        high->set, low->set

void nsperl2_Ns_SetMove(nsperl2_Ns_Set *from, nsperl2_Ns_Set *to)
    ALIAS:
        move = 1
    C_ARGS:
        from->set, to->set

void
Ns_SetPrint(self)
	nsperl2_Ns_Set * self
    ALIAS:
        print = 1
    C_ARGS:
        self->set

int
Ns_SetPut(self, key, value)
	nsperl2_Ns_Set * self
	char *	key
	char *	value
    ALIAS:
        put = 1
    C_ARGS:
        self->set, key, value

void
Ns_SetPutValue(self, index, value)
	nsperl2_Ns_Set * self
	int	index
	char *	value
    ALIAS:
        put_value = 1
    C_ARGS:
        self->set, index, value



# need to return an AV, loop over the null terminated array from setsplit
# and push each nsset into the AV
#Ns_Set **
#Ns_SetSplit(self, sep)
#	nsperl2_Ns_Set * self
#	char	sep

void
Ns_SetTrunc(self, size)
	nsperl2_Ns_Set * self
	int	size
    ALIAS:
        truncate = 1
    C_ARGS:
        self->set, size

int
Ns_SetUnique(self, key)
	nsperl2_Ns_Set * self
	char *	key
    ALIAS:
        unique = 1
    C_ARGS:
        self->set, key

#int
#uniqueCmp(self, key, arg2)
#	nsperl2_Ns_Set * self
#	char *	key
#	int ( * cmp ) ( char * s1, char * s2 )	arg2

void
Ns_SetUpdate(self, key, value)
	nsperl2_Ns_Set * self
	char *	key
	char *	value
    ALIAS:
        update = 1
    C_ARGS:
        self->set, key, value

