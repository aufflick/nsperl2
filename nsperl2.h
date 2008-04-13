#ifndef NSPERL2_H
#define NSPERL2_H

#include <assert.h>

/* nsd.h must come before perl due to extraneous STRINGIFY definition */
#include "ns.h"
#include "nsd.h"

#undef STRINGIFY

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

typedef Tcl_Obj nsperl2_TclCodeObj;

SV *tcl_obj_to_sv(Tcl_Interp *, Tcl_Obj *, int expand_lists);
SV *tcl_listobj_to_sv(Tcl_Interp *, Tcl_Obj *);
SV *tcl_strobj_to_sv(Tcl_Obj *);
SV *tcl_boolobj_to_sv(Tcl_Interp *, Tcl_Obj *);
SV *tcl_doubleobj_to_sv(Tcl_Interp *, Tcl_Obj *);
SV *tcl_intobj_to_sv(Tcl_Interp *, Tcl_Obj *);

Tcl_Obj *sv_to_tcl_obj (SV *);
Tcl_Obj *sv_to_tcl_strobj (SV *);
Tcl_Obj *iv_to_tcl_obj (SV *);
Tcl_Obj *nv_to_tcl_obj (SV *);
Tcl_Obj *av_to_tcl_obj (SV *);
Tcl_Obj *hv_to_tcl_obj (SV *);

typedef struct {
        Ns_Set *set;
        int persist_tcl;
        int persist_perl;
        const char *setId;
} nsperl2_Ns_Set;

Tcl_Interp *__nsperl2_get_tcl_interp(void);
NsInterp *__nsperl2_get_itPtr(void);

/* get the current itPtr for the tcl interpreter as per tclinit.c - is this public?? */
#define __nsperl2_get_itPtr_from_interp(interp) Tcl_GetAssocData ((interp), "ns:data", NULL)
nsperl2_Ns_Set *nsperl2_Ns_Set_new(char *name, Ns_Set *set, char *setId, int persist_perl, int persist_tcl);

typedef struct {
    PerlInterpreter *perl_interp;
} perl_context;

typedef struct {
    PerlInterpreter *perl_master_interp;
    char *param_path;
    char *init_script;
    char *init_sub;
    char *server;
} perl_master_context;

void nsperl2_delete_assoc_perl( ClientData clientData, Tcl_Interp *interp);
void nsperl2_free_master_context (void *context);
perl_context *nsperl2_get_assoc_perl_context (Tcl_Interp *interp);
void nsperl2_delete_assoc_perl( ClientData clientData, Tcl_Interp *interp);


void set_nsperl2_globals (PerlInterpreter *, Tcl_Interp *interp, Ns_Conn *conn);
int nsperl2_call_perl (Tcl_Interp *interp, Ns_Conn *conn, char *sub, SV *sub_sv, int objc, Tcl_Obj **objv, SV *perl_arg, int list_context);

typedef struct {
    char *perl_sub;
    char *dispatch_key;
    SV *perl_args_frozen;
    Tcl_Obj *tcl_args;
    int perlish;
} nsperl2PerlRequestContext;


#endif
